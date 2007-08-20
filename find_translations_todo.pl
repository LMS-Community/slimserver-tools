#!/usr/bin/perl

## find_translations_todo.pl
#
# a. searches through any directories given on the command line with --dirs flag (defaults to .)
# b. finds all occurrences of files that end in strings.txt (thus, also picks up global_strings.txt)
# c. reads through each strings file and determines whether all supported locales (given by --langs flag or defaults to @default_supported_langs array) have been translated
# d. outputs to STDOUT all strings needed for translation and what locales currently exist for it
#
## first version: bklaas 08.07

use strict;
use File::Find;
use Getopt::Long;

my @default_supported_langs = qw/ EN DE ES IT FR NL /;
my $command_args    = command_args();
my $xml_template    = get_xml_template();
my $supported_langs = $command_args->{'langs'};
my $dirs            = $command_args->{'dirs'};

my %supported_langs = map { $_ => '1' } @$supported_langs;

my $strings_files = get_strings_files();

my @strings_to_translate;

print $xml_template->{'root_header'} if $command_args->{'format'} eq 'xml';

for my $string_file (@$strings_files) {
	my $slurp = 0;
	my %got_it; my @strings;
	open(STRINGS,"<$string_file") or die "$!";
	my $output;
	while(<STRINGS>) {
		chomp;
		s/[\t\s]+$//;
		next unless /^[\t\s]*[A-Z0-9]/;
		if (/^[A-Z0-9]/) {
			# first deal with the last slurp
			if ($slurp) {
				$output .= compare_hashes(\%got_it, $slurp, \@strings);
			}
			$slurp = $_;
			%got_it = (); @strings = ();
			next;
		}
		if ($slurp && /^[\t\s]+[A-Z][A-Z]/) {
			s/^[\t\s]+//;
			my %data;
			($data{'lang'}, $data{'string'}) = split /\t/;	
			$got_it{$data{'lang'}}++;
			push @strings, \%data;
		}
	}
	if ($slurp) {
		$output .= compare_hashes(\%got_it, $slurp, \@strings);
	}
	close(STRINGS);
	if ($output) {
		if ($command_args->{'format'} eq 'xml') {
			my $filepath_header = $xml_template->{'filepath_header'};
			$filepath_header =~ s/__FILEPATH/$string_file/g;
			print $filepath_header;
			print $output;
			print $xml_template->{'filepath_footer'};
		} else {
			print "FILE:\t" . $string_file . "\n" if $command_args->{'verbose'};
			print $output;
		}
	}
}

print $xml_template->{'root_footer'} if $command_args->{'format'} eq 'xml';

sub compare_hashes {
	my ($seen, $string, $strings) = @_;
	my $missing_translations = missing_translations($seen);
	my $return = "";
	if ($missing_translations) {
		if ($command_args->{'format'} eq 'xml') {
			my $string_header = $xml_template->{'string_header'};
			$string_header =~ s/__STRING/$string/;
			$return .= $string_header;
			for my $line (@$strings) {
				my $string_data = $xml_template->{'string_data'};
				$string_data =~ s/__LANG/$line->{'lang'}/;
				$string_data =~ s/__TRANSLATION/$line->{'string'}/;
				$return .= $string_data;
			}
			$return .= $xml_template->{'string_footer'};
		} else {
			$return .= "$string\n";
			for my $line (@$strings) {
				$return.= "\t$line->{'lang'}\t$line->{'string'}\n";
			}
			$return .= "\n";
		}
	}
	return $return;
}

sub missing_translations {
	my $compare = shift;
	my $missing = 0;
	for (keys %supported_langs) {
		$missing++ unless exists $compare->{$_};
	}
	return $missing;
}

sub get_strings_files {
	my @return;
	find sub {
		my $file = $File::Find::name;
		push @return, $file if $file =~ /strings\.txt$/;
	}, @$dirs;
	return \@return;
}

sub command_args {
	my %args;
	my $usage = "usage: find_translations_todo.pl (--verbose) (--format [xml|txt]) (--dirs '...') (--langs '...')
	--format defaults to txt. xml is the other option.
	--verbose prints file information on each line
	argument to --dirs is a list of dirs to search 
		(defaults to '.')
	argument to --langs is a list of languages to check for translation 
		(defaults to @default_supported_langs)\n";
	GetOptions(
		'help'	=>	\$args{'help'},
		'dirs=s'	=>	\$args{'dirstring'},
		'langs=s'	=>	\$args{'langstring'},
		'format=s'	=>	\$args{'format'},
		'verbose'	=>	\$args{'verbose'},
	);
	if ($args{'help'}) {
		print $usage;
		exit;
	}
	# parse dirs by spaces 
	my @dirs = ( '.' );
	if ($args{'dirstring'}) {
		@dirs = split/\s+/, $args{'dirstring'};
	}
	$args{'dirs'} = \@dirs;

	$args{'format'} eq 'txt' unless $args{'format'} eq 'xml';

	my @langs = @default_supported_langs;
	if ($args{'langstring'}) {
		@langs = split/[^A-Z]+/, $args{'langstring'};
	}
	$args{'langs'} = \@langs;

	return \%args;
}

sub get_xml_template {
	my %return;
	$return{'root_header'} = <<XMLHEAD;
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
	<Root>
XMLHEAD
	$return{'filepath_header'} = <<FILEPATH;
		<File RelativePath="__FILEPATH">
FILEPATH
	$return{'filepath_footer'} = "\t\t</File>\n";

	$return{'string_header'} = <<XMLSTRING;
			<TranslationUnit Id="__STRING">
XMLSTRING
	$return{'string_footer'} = "\t\t\t</TranslationUnit>\n";
	$return{'string_data'} = <<STRINGDATA;
				<Target Language = "__LANG">__TRANSLATION</Target>
STRINGDATA
	$return{'root_footer'} = "\t</Root>\n";
	return \%return;
}
