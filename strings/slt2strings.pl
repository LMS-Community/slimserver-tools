#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Data::Dumper;
use File::Find;
use File::Spec::Functions qw/:ALL/;

my @defaultLanguages = qw/ EN CS DA DE ES FI IT FR NL NO SV PL RU /;
my @defaultStringfiles = qw/ strings.txt global_strings.txt /;
my %strings;
my $debug = 1;

my $args = getArgs();

# TODO: make input folder configurable
my $dirname = rel2abs('.');
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

			print "Duplicate value? $1, $2, $lang\n" if ($strings{$2}{$lang});

			$strings{$2}{$lang} = $3;
			$strings{$2}{$lang} =~ s/\s+$//;
			# Bug 8613: make sure a space is prepended on JIVE_ALLOWEDCHARS* strings
			if ($2 && $2 =~ /^ALLOWEDCHARS/) {
				if ($3 =~ /^\S/) {
					$strings{$2}{$lang} = ' ' . $strings{$2}{$lang};
				}
			}
		}
	}
	close(MYSTRINGS);

}
closedir(DIR);

my $tmpFolder = catdir($dirname, 'tmp');
unless (-d $tmpFolder) {
	mkdir $tmpFolder or die "Couldn't create $tmpFolder: $!\n";
}

# search target folder for strings files
find sub {
	my $stringsFile = $File::Find::name;
	my $shortName = $_;

	if (grep { $stringsFile =~ /$_$/ } @defaultStringfiles) {

		print "Processing $stringsFile\n" if ($debug);

		if (-w $stringsFile) {

			my ($tmpFile, $tmpFolder) = getTmpFile($shortName, $File::Find::dir);

			my $originalStrings = getStringsFile($stringsFile);

			mergeCustomStrings(\$originalStrings);

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


1;


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
	while ($stringCopy =~ /(^\S+.*?)(^\s*\n|\z)/gsmi) {

		my $stringsToTranslate = $1;

		# get the string token
		$stringsToTranslate =~ /^(\S+)$/m;
		my $stringName = $1;

		# no white space allowed in token
		if (($stringName !~ /(?:#|\s)/) && defined $strings{$stringName}) {
			foreach my $language (keys %{$strings{$stringName}}) {
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
	my $stringsToSort = shift;

	$stringsToSort =~ /^([\w\-]+)(.*)/smi;
	my $stringName = $1;
	my @translatedStrings = split(/\n/, $2);

	@translatedStrings = sort(@translatedStrings);
	return $stringName . join("\n", @translatedStrings) . "\n";
}

sub getArgs {
	my %args;
	my $usage = "usage: slt2strings.pl (--langs '...') (--quiet) --dir '...'
	argument to --dir is the root folder of the directory tree we want to search for strings.txt files

	argument to --langs is a list of languages to check for translation 
		(defaults to @defaultLanguages)\n";

	my $quiet;

	GetOptions(
		'help'      => \$args{'help'},
		'langs=s'   => \$args{'langstring'},
		'quiet'     => \$quiet,
		'dir=s'     => \$args{'dir'},
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
	$args{'langs'} = \@langs;

	return \%args;
}
