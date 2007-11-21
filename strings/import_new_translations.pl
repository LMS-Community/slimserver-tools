#!/usr/bin/perl

# THIS SCRIPT IS A BIT OF A HAIRBALL
# 	I can only get XML::Simple to work with UTF-8 when using this script from an Ubuntu machine
# 	** OS X is munging UTF-8 strings **
#
# 	Eventually, this needs to be rewritten more generically to use XSLT to pull in from XML and write out to strings.txt
#	Also, the plan moving forward is to send the SLT team ALL strings, including those that are translated, and
#	to have all strings returned, which is a simpler path (but not exactly covered by this script)

## import_new_translations.pl
#
# a. searches through rootpath given on the command line with --rootpath flag
# b. finds all occurrences of files that end in strings.txt (thus, also picks up global_strings.txt)
# c. parses localized files (from the dir given by the --infiles flag) and stores translations in perl data structure
# d. reads through each strings file and appends strings that have been translated, 
#    if none exist in the current strings.txt file for that lang
#
## first version: bklaas 09.07

use strict;
use File::Find;
use Getopt::Long;
use XML::Simple;
use utf8;
use Encode;

my $xml = new XML::Simple;


my @default_supported_langs = sort qw/ DE ES FR HE IT NL /;
my $args            = command_args();
my $supported_langs = $args->{'langs'};
my $rootpath        = $args->{'rootpath'};
my $infiles         = $args->{'infiles'};

my %supported_langs = map { $_ => '1' } @$supported_langs;

my %DATA;
my %STRINGS; # fullpath is first key, Id is second key, LANG is third key, translation is value
$DATA{'langs'} = $supported_langs;
my @strings_files = ();

for my $lang (@$supported_langs) {
	my $string_file = $args->{'infiles'} . "/strings." . lc($lang) . ".xml";

	# read XML file
	print "$string_file\n";
	next if (! -e $string_file);
	my $raw = $xml->XMLin($string_file, ForceArray => 1 );
	my $data = $raw->{'file'};
	for my $elem (@$data) {
		my $relPath = $elem->{'original'};
#		$relPath =~ s/\/+Users\/bklaas\/jive\///;
		my $fullpath = $args->{'rootpath'} . "/" . $relPath;
	$fullpath = $relPath;
		if (-e $fullpath) {
			push @strings_files, $elem->{'original'};
			my $ref = $elem->{'body'};

			for my $fileTrans (@$ref) {
				my $stringTrans = $fileTrans->{'trans-unit'};
				for my $id (sort keys %$stringTrans) {
					my $translation = $stringTrans->{$id}{'target'}->[0];
					#print "|$translation|\n";
					$STRINGS{$fullpath}{$id}{$lang} = $translation;
					#print "$fullpath\t$id\t$lang\t$STRINGS{$fullpath}{$id}{$lang}\n";
				}
			}
		}
		
	}
}
close(OUT);

my $strings_files = get_strings_files();
$DATA{'files'} = $strings_files;

my $i = 1;

for my $string_file (@$strings_files) {

	# 2 passes on the string file.
	# pass 1: pull in all the STRINGs and the translations
	# pass 2: open a second file for writing, 
	# filling in missing translations with whatever we have from XML files

	if ($string_file =~ /\.txt$/i) {
		# pass 1
		my $already_translated = readTxtFile($string_file);

		# pass 2
		writeTxtFile($already_translated, $string_file);		
	}

	# Windows installer file
	elsif ($string_file =~ /\.iss$/i) {
		# pass 1
		my $already_translated = readIssFile($string_file);

		# pass 2
		writeIssFile($already_translated, $string_file);		
	} 
	

	$i++;
}
exit 1;

sub writeTxtFile {
	my ($already_translated, $string_file) = @_;

	open(IN,"<:utf8", $string_file) or die "$!";
	open(OUT,'>:utf8', "${string_file}.new") or die "$!";
	#open(OUT,">:utf8", "/tmp/test/strings$i.txt") or die "$!";
	binmode(STDERR,':utf8');
	my $string = '';
	my $lineNumber = 0;
	while(<IN>) {

		$lineNumber++;
		#next if $lineNumber == 1;
		if ($lineNumber == 1) {
			next;
		}

		# remove newline chars and trailing tabs/spaces
		chomp; s/[\t\s]+$//; 

		# this is a STRING
		if (/^[A-Z0-9]/) {
			$string = $_;
			print OUT $_ . "\n";
			for my $lang (sort 'EN', @$supported_langs) {
				if ($already_translated->{$string_file}{$string}{$lang}) {
					print OUT "\t" . $lang . "\t" . $already_translated->{$string_file}{$string}{$lang} . "\n";
				} elsif ($STRINGS{$string_file}{$string}{$lang}) {
					# hack to deal with newline not showing up in translations
					if ($lang ne 'EN' && $already_translated->{$string_file}{$string}{'EN'} =~ /^\\n/ && $STRINGS{$string_file}{$string}{$lang} !~ /^\\n/) {
						$STRINGS{$string_file}{$string}{$lang} = '\n' . $STRINGS{$string_file}{$string}{$lang};
					}
					print OUT "\t" . $lang . "\t" . $STRINGS{$string_file}{$string}{$lang} . "\n";
				}
			}
			next;
		# this is a TRANSLATION. Skip it because we dealt with this when hitting the STRING
		} elsif ($string ne "" && /^[\t\s]+[A-Z][A-Z]/) {
			next;
		# this is neither, so just print the raw line, unchanged
		} else {
			print OUT $_ . "\n";
		}
	}
	close(IN);
	close(OUT);
	unlink($string_file);	
	rename("${string_file}.new", $string_file);
}

sub writeIssFile {
	my ($already_translated, $string_file) = @_;

	# do NOT use utf8 for Windows installer files 
	open(IN, $string_file) or die "$! - $string_file";
	open(OUT, ">${string_file}.new") or die "$! - $string_file";
	my $string = '';

	while(<IN>) {
		# remove newline chars and trailing tabs/spaces
		chomp; s/[\t\s]+$//; 

		# this is a new STRING
		if (/([a-z]{2})\.(\w+?)=(.*)/i) {
			$string = $2;
			for my $lang ('EN', @$supported_langs) {
				if ($STRINGS{$string_file}{$string}{$lang}) {
					# hack to deal with newline not showing up in translations
					if ($lang ne 'EN' && $already_translated->{$string_file}{$string}{'EN'} =~ /^\\n/ && $STRINGS{$string_file}{$string}{$lang} !~ /^\\n/) {
						$STRINGS{$string_file}{$string}{$lang} = '\n' . $STRINGS{$string_file}{$string}{$lang};
					}
					print OUT lc($lang) . '.' . $string . '=' . $STRINGS{$string_file}{$string}{$lang} . "\n";
				}
				elsif ($already_translated->{$string_file}{$string}{$lang}) {
					print OUT lc($lang) . '.' . $string . '=' . $already_translated->{$string_file}{$string}{$lang} . "\n";
				}
			}
			$STRINGS{$string_file}{$string} = undef;
			$already_translated->{$string_file}{$string} = undef;
			next;

		# this is neither, so just print the raw line, unchanged
		} else {
			print OUT $_ . "\n";
		}
	}
	close(IN);
	close(OUT);
	unlink($string_file);	
	rename("${string_file}.new", $string_file);
}

sub get_strings_files {
	my @return;
	find sub {
		my $file = $File::Find::name;
		push @return, $file if $file =~ /strings\.(txt|iss)$/;
	}, $args->{'rootpath'};
	return \@return;
}

sub command_args {
	my %args;
	my $usage = "usage: find_translations_todo.pl --infiles <path_to_xml_files> --rootpath '...' (--langs '...') | (--help)
	argument to --infiles is a path to the directory where the localized XML files are
		(defaults to '.')
	argument to --rootpath is the base path to where all the strings.txt files are
		(defaults to '')
	argument to --langs is a list of languages to check for translation 
		(defaults to @default_supported_langs)\n";
	GetOptions(
		'help'	=>	\$args{'help'},
		'infiles=s'	=>	\$args{'infiles'},
		'rootpath=s'	=>	\$args{'rootpath'},
		'langs=s'	=>	\$args{'langstring'},
		'verbose'	=>	\$args{'verbose'},
	);
	if ($args{'help'}) {
		print $usage;
		exit;
	}

	my @langs = @default_supported_langs;
	if ($args{'langstring'}) {
		@langs = split/[^A-Z]+/, $args{'langstring'};
	}
	$args{'langs'} = \@langs;

	return \%args;
}

sub readTxtFile {
	my $string_file = shift;
	my %return;
	open(STRINGS,"<:utf8", $string_file) or die "$!";
	my $string;
	my $lineNumber = 0;
	while(<STRINGS>) {

		$lineNumber++;
		if ($lineNumber == 1) {
			next;
		}
		my $line = $_;

		# remove newline chars and trailing tabs/spaces
		chomp; s/[\t\s]+$//; 

		# skip all lines that don't start with a number/capital letter 
		# or zero or more tabs/spaces, followed by a number/capital letter
		next unless /^\t*[A-Z0-9]/; 

		# this is a STRING
		if (/^[A-Z0-9]/) {
			$string = $_;
		# this is a TRANSLATION
		} elsif ($string ne "" && /^\t+[A-Z][A-Z]/) {
			s/^\t+//;
			my ($lang, @translation) = split /\t+/;
			my $translation = join(' ', @translation);
			$return{$string_file}{$string}{$lang} = $translation;
		}
	}
	close(STRINGS);
	return \%return;
}

sub readIssFile {
	my $string_file = shift;
	my %return;
	open(STRINGS, $string_file) or die "$!";
	my $string;
	my $lineNumber = 0;
	while(<STRINGS>) {

		# remove newline chars and trailing tabs/spaces
		chomp; s/[\t\s]+$//; 

		next unless /([a-z]{2})\.(\w+?)=(.*)/i;
		(my $lang, my $string, my $translation) = (uc($1), $2, $3);

		if (!$DATA{'data'}{$string_file}{$string}) {
			# add {FILE}{STRING} to %DATA, with blanks for all supported langs
			for my $lang (@$supported_langs) {
				$DATA{'data'}{$string_file}{$string}{$lang} = "";
			}				
		}

		$return{$string_file}{$string}{$lang} = $translation;

	}
	close(STRINGS);

	return \%return;
}
