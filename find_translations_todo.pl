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
my $supported_langs = $command_args->{'langs'};
my $dirs            = $command_args->{'dirs'};

my %supported_langs = map { $_ => '1' } @$supported_langs;

my $strings_files = get_strings_files();

my @strings_to_translate;
for my $string_file (@$strings_files) {
	my $slurp = 0;
	my %got_it; my @strings;
	open(STRINGS,"<$string_file") or die "$!";
	while(<STRINGS>) {
		chomp;
		s/[\t\s]+$//;
		next unless /^[\t\s]*[A-Z0-9]/;
		if (/^[A-Z0-9]/) {
			# first deal with the last slurp
			if ($slurp) {
				compare_hashes(\%got_it, $slurp, \@strings);
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
		compare_hashes(\%got_it, $slurp, \@strings);
	}
	close(STRINGS);
}

sub compare_hashes {
	my ($seen, $string, $strings) = @_;
	my $missing_translations = missing_translations($seen);
	if ($missing_translations) {
		print "$string\n";
		for my $line (@$strings) {
			print "\t$line->{'lang'}\t$line->{'string'}\n";
		}
		print "\n";
	}
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
	my $usage = "usage: find_translations_todo.pl (--dirs '...') (--langs '...')
	argument to --dirs is a list of dirs to search 
		(defaults to '.')
	argument to --langs is a list of languages to check for translation 
		(defaults to @default_supported_langs)\n";
	GetOptions(
		'help'	=>	\$args{'help'},
		'dirs=s'	=>	\$args{'dirstring'},
		'langs=s'	=>	\$args{'langstring'},
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

	my @langs = @default_supported_langs;
	if ($args{'langstring'}) {
		@langs = split/[^A-Z]+/, $args{'langstring'};
	}
	$args{'langs'} = \@langs;

	return \%args;
}
