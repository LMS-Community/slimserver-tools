#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Data::Dump;
use File::Find;
use File::Spec::Functions qw/:ALL/;

my @defaultLanguages = qw/ EN CS DA DE ES FI IT FR NL NO SV PL RU /;
my $args = getArgs();

my @defaultStringfiles = $args->{format} eq 'iss' ? qw/ strings.iss / : qw/ strings.txt global_strings.txt /;

if ($args->{format} eq 'json') {
	require File::Slurp;
	require JSON::XS;
}

my %strings;
my $debug = 0;

my $dirname = rel2abs('.');

# TODO: make input folder configurable
if ( $args->{'custom-strings'} ) {
	parseStringsFile($args, catdir($args->{dir}, 'custom-strings.txt'));
}
else {
	parseSLTFiles($args, $dirname);
}

# search target folder for strings files
if ($args->{format} eq 'json') {
	my $stringsFile = catdir($args->{dir}, 'strings.json');
	
	# read original file if available, make sure the new translations don't miss a string
	my $oldStrings = eval {
		my $s = File::Slurp::read_file($stringsFile);
		utf8::encode($s);
		JSON::XS::decode_json($s);
	} || {};
	
	if ($@) {
		warn "Problem reading original file? $@\n";
	}

	foreach my $key (keys %$oldStrings) {
		if (!defined $strings{$key}) {
			print "Translation missing for string $key\n";
			$strings{$key} = $oldStrings->{$key};
		}
		else {
			foreach my $lang (keys %{$oldStrings->{$key}}) {
				if (!$strings{$key}{$lang}) {
					$strings{$key}{$lang} = $oldStrings->{$key}->{$lang};
				}
			}
		}
	}	

	File::Slurp::write_file(
		catdir($args->{dir}, 'strings.json'),
		JSON::XS->new->pretty->encode(\%strings)
	);
}
else {
	my $tmpFolder = catdir($dirname, 'tmp');
	unless (-d $tmpFolder) {
		mkdir $tmpFolder or die "Couldn't create $tmpFolder: $!\n";
	}
	
	find sub {
		return unless keys %strings;
		
		my $stringsFile = $File::Find::name;
		my $shortName = $_;
	
		if ( $_ ne 'custom-strings.txt' && grep { $stringsFile =~ /$_$/ } @defaultStringfiles ) {
	
			print "Processing $stringsFile\n"; # if ($debug);
	
			if (-w $stringsFile) {
	
				my ($tmpFile, $tmpFolder) = getTmpFile($shortName, $File::Find::dir);
	
				my $originalStrings = getStringsFile($stringsFile);
				
				if ($args->{format} eq 'iss') {
					mergeCustomIssStrings(\$originalStrings);
				}
				else {
					mergeCustomStrings(\$originalStrings);
				}
	
				open(STRINGS, ">:utf8", $tmpFile) or die "Couldn't open $tmpFile for writing: $!\n";
				binmode STRINGS;
				print STRINGS $originalStrings;
				close(STRINGS);
	
				rename $tmpFile, $stringsFile;
	
				rmdir $tmpFolder;
			}
		
			else {
				print "$stringsFile is not writable\n";
			}
		}
	
	}, ($args->{'dir'});

	# write file with unknown translations
	if (keys %strings) {
		
		my $stringsFile = catdir($tmpFolder, 'unknown-strings.txt');
	
		print "Writing out unknown strings to $stringsFile\n" if ($debug);
	
		open(STRINGS, ">:utf8", $stringsFile) or die "Couldn't open $stringsFile for writing: $!\n";
		binmode STRINGS;
	
		foreach my $stringName (sort keys %strings) {
			print STRINGS "$stringName\n";
	
			foreach my $language (keys %{$strings{$stringName}}) {
				print STRINGS "\t$language\t$strings{$stringName}->{$language}\n";
			}
	
			print STRINGS "\n";
		}
	
		close(STRINGS);
	}
}


1;

# copied from Slim::Utils::Strings
sub parseStringsFile {
	my ($args, $file) = @_;
	
	# Force the UTF-8 layer opening of the strings file.
	open(my $fh, $file) || do {
		die "Couldn't open $file - FATAL!";
	};
	
	my $string = '';
	my $language = '';
	my $stringname = '';
	my $stringData = {};
	my $ln = 0;

	my $storeString = sub {
		my ($token, $translations) = @_;
		
		foreach my $k (keys %$translations) {
			my $v = $translations->{$k};
			next unless defined($k) && defined($v);
			
			$k = 'ZH_CN' if $k eq 'ZH_HANS';
			
			$strings{$token} ||= {};
			$strings{$token}->{$k} = $v;
		}
	};

	LINE: for my $line ( <$fh> ) {

		$ln++;

		# skip lines starting with # (comments?)
		next if $line =~ /^#/;
		# skip lines containing nothing but whitespace
		# (this includes empty lines)
		next if $line !~ /\S/;

		if ($line =~ /^(\S+)$/) {

			$storeString->($stringname, $stringData);

			$stringname = $1;
			$stringData = {};
			$string = '';
			next LINE;

		} elsif ($line =~ /^\t(\S*)\t(.+)$/) {

			my $one = $1;
			$string = $2;

			if ($one =~ /./) {
				$language = uc($one);
			}

			if (defined $stringData->{$language}) {
				$stringData->{$language} .= "\n$string";
			} else {
				$stringData->{$language} = $string;
			}

		} else {

			warn "Parsing line $ln: $line";
		}
	}

	$storeString->($stringname, $stringData) if $stringname && keys %$stringData;
	
	close $fh;
}

sub parseSLTFiles {
	my ($args, $dirname) = @_;
	
	opendir(DIR, $dirname) or die "can't opendir $dirname: $!";
	
	my $fileFilter = join('|', @{$args->{'langs'}});
	$fileFilter = qr/-($fileFilter)\.txt$/i;
	
	# process all *-{Language ID}.txt files
	while (defined (my $sltFile = readdir(DIR))) {
	
		next unless $sltFile =~ $fileFilter;
		my $lang = uc($1);
	
		print "Reading $sltFile...\n" if ($debug);
	
		open(MYSTRINGS, "<:utf8", $sltFile) or (warn "Couldn't open $sltFile for reading: $!\n" && next);
		binmode MYSTRINGS;
	
		foreach (<MYSTRINGS>) {
			chomp;
	
			if (/^(.*)__(.*?)\t(.*)$/) {
				
				my ($token, $string) = ($2, $3);
	
				print "Duplicate value? $1, $token, $lang\n" if ($strings{$token}{$lang});
	
				($string) = split /\t/, $string;
				$string =~ s/\s+$//;
	
				# Bug 8613: make sure a space is prepended on JIVE_ALLOWEDCHARS* strings
				if ($token && $token =~ /^ALLOWEDCHARS/) {
					if ($string =~ /^\S/) {
						$string = ' ' . $string;
					}
				}
	
				$strings{$token}{$lang} = $string;
			}
		}
		close(MYSTRINGS);
	
	}
	closedir(DIR);
}

sub getTmpFile {
	my $shortName = shift;
	my $currdir   = shift;

	my ($volume, $directories, $file) = splitpath($currdir, 1);
	my @directories = splitdir($directories);
	$currdir = pop @directories;

	my $tmpFolder = catdir($dirname, 'tmp', $currdir);
	unless (-d $tmpFolder) {
		mkdir $tmpFolder or die "Couldn\'t create $tmpFolder: $!\n";
	}

    return (catdir($tmpFolder, $shortName), $tmpFolder);
}

sub getStringsFile {
	my $localStringsFile = shift;
	my $myStrings;

	local $/ = undef;
	open(STRINGS, $localStringsFile) or die "Couldn't open $localStringsFile for reading: $!\n";
	$myStrings = <STRINGS>;
	close(STRINGS);

	return $myStrings;
}

sub mergeCustomStrings {
	my ($originalStrings) = @_;
	my $stringCopy = $$originalStrings;

	# get strings one after another in a block of string token and translations
	while ($stringCopy =~ /(^\w+.*?)(^\s*\n|\z)/gsmi) {

		my $stringsToTranslate = $1;

		# get the string token
		$stringsToTranslate =~ /^(\S+)$/m;
		my $stringName = $1;

		# no white space allowed in token
		if (($stringName !~ /(?:#|\s)/) && defined $strings{$stringName}) {
			foreach my $language (keys %{$strings{$stringName}}) {
				
				next if $language ne 'EN' && $strings{$stringName}->{EN} && $strings{$stringName}->{$language} eq $strings{$stringName}->{EN};
				
				# try to replace the translation...
				if ($stringsToTranslate !~ s/^(\t$language\t).+?$/$1$strings{$stringName}->{$language}/ism) {
					# ... or simply add it
					$stringsToTranslate =~ s/(^$stringName\n)/$1\t$language\t$strings{$stringName}->{$language}\n/ism;
				}
			}
			$stringsToTranslate = sortStrings($stringsToTranslate);

			$$originalStrings =~ s/(^$stringName\s.*?)(^\s*\n|\z)/$stringsToTranslate\n/smi;
			delete $strings{$stringName};
		}
		elsif ($debug && $stringName !~ /(?:#|\s)/ && !defined $strings{$stringName}) {
			print "no translation found for: $stringName\n";
		}
	}
}

# sorts the different translations for a string according to their language code
sub sortStrings {
	my @translatedStrings = grep /\w/, split(/\n/, shift);

	@translatedStrings = sort {
		return -1 if $a =~ /^\w/;
		return 1 if $b =~ /^\w/;
		return -1 if ($a =~ /^#/ && $b !~ /^#/);
		return 1 if ($b =~ /^#/ && $a !~ /^#/);
		
		$a cmp $b;
	} @translatedStrings;
	return join("\n", @translatedStrings) . "\n";
}


# .iss files for InnoSetup have a slightly different structure
sub mergeCustomIssStrings {
	my ($originalStrings) = @_;

	foreach my $key (sort keys %strings) {
		# skip all uppercase IDs - we don't use them in .iss files
		next if length($key) > 3 && $key !~ /[a-z]/;

		foreach my $lang (sort keys %{$strings{$key}}) {

			my $id  = lc($lang) . '.' . $key;
			   $id  =~ s/^cs/cz/;
			   
			my $val = $strings{$key}->{$lang};
			
			next unless $id && $val;
			
			if ($$originalStrings !~ s/^$id=.*?$/$id=$val/ism) {

				$$originalStrings .= "\n$id=$val";
			}

		}
	}
	
	my $lastId = '';
	# clean up the strings file
	$$originalStrings = join("\n", 
		# separate blocks of identical IDs with an empty line
		map {
			my ($id) = $_ =~ /[a-z]{2}\.(.*?)=/i;
			
			if ($id ne $lastId) {
				$_ = "\n" . $_;
				$lastId = $id;
			}
			$_;
		} 
		
		#strip out empty lines
		grep /[a-z]{2}\..*?=/i, 
		
		# sort strings by ID, then language
		sort {
			my ($langA, $idA) = $a =~ /([a-z]{2})\.(.*?)=.*/i;
			my ($langB, $idB) = $b =~ /([a-z]{2})\.(.*?)=.*/i;
			
			$langA ||= '';
			$langB ||= '';
			$idA ||= '';
			$idB ||= '';
			
			"$idA.$langA" cmp "$idB.$langB";
		} split /\n/, $$originalStrings
	);
	
	$$originalStrings =~ s/^cs/cz/mig;
}

sub getArgs {
	my %args;
	my $usage = "
usage: slt2strings.pl (--langs '...') (--format=[iss|json|txt]) (--quiet) --dir '...'
	argument to --dir is the root folder of the directory tree we want to search for strings.txt files

	argument to --langs is a list of languages to check for translation 
		(defaults to @defaultLanguages)\n

	--customstrings - read a local custom-strings.txt file rather than SLT files
		
	--format=iss will merge the files in the InnoSetup Strings file format
	--format=json will dump a json file of the language hash

";

	my $quiet;

	GetOptions(
		'help'    => \$args{'help'},
		'langs=s' => \$args{'langstring'},
		'quiet'   => \$quiet,
		'dir=s'   => \$args{'dir'},
		'format=s'=> \$args{'format'},
		'customstrings' => \$args{'custom-strings'},
	);

	if ($args{'help'} || !$args{'dir'}) {
		print $usage;
		exit;
	}

	my @langs = @defaultLanguages;
	if ($args{'langstring'}) {
		@langs = split/[^A-Z]+/, $args{'langstring'};
	}

	$debug = !$quiet;
	$args{langs}  = \@langs;
	$args{format} = lc($args{format} || 'txt');

	return \%args;
}
