#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Data::Dumper;
use File::Find;
use File::Spec::Functions;

my @defaultLanguages = qw/ EN DA DE ES FI IT FR NL NO SV /;
my %strings;
my $debug;

# FIXME
my $dirname = '.';

my $args = getArgs();

foreach my $lang (@{$args->{'langs'}}) {
	my $fileName = "$args->{'product'}-$lang.txt";

	open(MYSTRINGS, "<:utf8", $fileName) or (warn "Couldn't open $fileName for reading: $!\n" && next);
	binmode MYSTRINGS;

	foreach (<MYSTRINGS>) {
		chomp;
		if (/^(.*)__(.*?)\t(.*)$/) {
			$strings{$1}{$2}{$lang} = $3;
			$strings{$1}{$2}{$lang} =~ s/\s+$//;
		}
	}
	close(MYSTRINGS);
}

if ($debug) {
	foreach my $mod (keys %strings) {
		my $localStringsFile = "$mod-strings.txt";
		open(STRINGS, ">>:utf8", $localStringsFile) or die "Couldn't open $localStringsFile for writing: $!\n";
		binmode STRINGS;

		foreach my $string (keys %{$strings{$mod}}) {
			print STRINGS sprintf("\n%s\n", $string);
	
			foreach my $lang (keys %{$strings{$mod}{$string}}) {
				print STRINGS sprintf("\t%s\t%s\n", uc($lang), $strings{$mod}{$string}{$lang});
			}
		}
	
		close(STRINGS);
	}	
}

# SqueezeCenter strings
if ($args->{'product'} eq 'strings') {
	processFile($args->{'dir'}, 'server')
}

elsif ($args->{'product'} eq 'squeezetray') {
	
}


1;

sub processFile {
	my ($targetfolder, $id) = @_;

	my $stringsFile = catdir($targetfolder, 'strings.txt');

	if (-w $stringsFile) {
		my $tmpFolder = catdir($targetfolder, time());
		mkdir $tmpFolder;

		my $originalStrings = getStringsFile($stringsFile);

		mergeCustomStrings(\$originalStrings, $id);

		$stringsFile = writeFiles(\$originalStrings, $tmpFolder);
		rename "$tmpFolder/strings.txt", $stringsFile;

		rmdir $tmpFolder;
	}

	else {
		print "$stringsFile is not writable\n";
	}
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
	my ($originalStrings, $id) = @_;
	my $stringCopy = $$originalStrings;

	# get strings one after another in a block of string token and translations
	while ($stringCopy =~ /(^\S+.*?)(^\s*\n|\z)/gsmi) {

		my $stringsToTranslate = $1;

		# get the string token
		$stringsToTranslate =~ /^(\S+)$/m;
		my $stringName = $1;

		# no white space allowed in token
		if (($stringName !~ /\s/) && defined $strings{$id}{$stringName}) {
			foreach my $language (keys %{$strings{$id}{$stringName}}) {
				# try to replace the translation...
				if ($stringsToTranslate !~ s/^(\t$language\t).+?$/$1$strings{$id}{$stringName}->{$language}/ism) {
					# ... or simply add it
					$stringsToTranslate =~ s/(^$stringName\n)/$1\t$language\t$strings{$id}{$stringName}->{$language}\n/ism;
				}
			}
			$stringsToTranslate = sortStrings($stringsToTranslate);

			$$originalStrings =~ s/(^$stringName\s.*?)(^\s*\n|\z)/$stringsToTranslate\n/smi;
#print "$stringName, ";
			delete $strings{$id}{$stringName};
		}
		else {
#			print "not translated: $stringName\n";
		}
	}
}

sub writeFiles {
#	my $newStrings = \%strings;
#	my $customStrings = shift;
	my $originalStrings = shift;
	my $tmpFolder = shift;
	
	# strings file	
	my $stringsFile = catdir($tmpFolder, 'strings.txt');
	open(STRINGS, ">:utf8", $stringsFile) or die "Couldn't open $stringsFile for writing: $!\n";
	binmode STRINGS;
	print STRINGS $$originalStrings;
	close(STRINGS);

	# write file with unknown translations
#	if (keys %{$newStrings}) {
#		$stringsFile = "$tmpFolder/unknown-strings.txt";
#		open(STRINGS, ">:utf8", $stringsFile) or die "Couldn't open $stringsFile for writing: $!\n";
#		foreach my $stringName (sort keys %{$newStrings}) {
#			print STRINGS "$stringName\n";
#
#			foreach my $language (keys %{$newStrings->{$stringName}}) {
#				print STRINGS "\t$language\t$newStrings->{$stringName}->{$language}\n";
#			}
#	
#			print STRINGS "\n";
#		}
#		close(STRINGS);
#	}
	
	return $stringsFile;
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
	my $usage = "usage: slt2strings.pl (--langs '...') (--product '...') --dir '...'
	argument to --dir is the root folder of the directory tree we want to search for strings.txt files

	argument to --langs is a list of languages to check for translation 
		(defaults to @defaultLanguages)

	argument to --product is a product id such as squeezecenter, squeezetray, squeezenetwork or firmware 
		(defaults to strings)\n";

	GetOptions(
		'help'      => \$args{'help'},
		'langs=s'   => \$args{'langstring'},
		'product=s' => \$args{'product'},
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

	$args{'langs'} = \@langs;

	$args{'product'} = 'strings' unless ($args{'product'} && $args{'product'} ne 'squeezecenter');

	return \%args;
}

1;

