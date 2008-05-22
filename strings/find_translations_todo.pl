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
use Template;

my @default_supported_langs = qw/ EN DA DE ES FI IT FR NL NO SV /;
my $args            = command_args();
my $supported_langs = $args->{'langs'};
my $dirs            = $args->{'dirs'};

my %supported_langs = map { $_ => '1' } @$supported_langs;

my %DATA;
my $strings_files = get_strings_files();
$DATA{'files'} = $strings_files;
$DATA{'langs'} = $supported_langs;

my %found;
my %missing;

for my $string_file (@$strings_files) {
	open(STRINGS,"<$string_file") or die "$!";
	my $string;

	if ($string_file =~ /\.txt$/i) {
		while(<STRINGS>) {
	
			# remove newline chars and trailing tabs/spaces
			chomp; s/[\t\s]+$//; 
	
			# skip all lines that don't start with a number/capital letter 
			# or zero or more tabs/spaces, followed by a number/capital letter
			next unless /^[\t\s]*[A-Z0-9]/; 
	
			# this is a STRING ID
			if (/^[A-Z0-9]/) {
				$string = $_;
				# add {FILE}{STRING} to %DATA, with blanks for all supported langs
				for my $lang (@$supported_langs) {
					$DATA{'data'}{$string_file}{$string}{$lang} = "";
					map { $missing{$_}++ } @$supported_langs;
				}
			}
	
			# this is a TRANSLATION
			elsif ($string ne "" && /^[\t\s]+[A-Z][A-Z]/) {
				s/^[\t|\s]+//;
				my ($lang, @translation) = split /[\t]+/;
				$DATA{'data'}{$string_file}{$string}{$lang} = $translation[0];
				$DATA{'comment'}{$string_file}{$string}{$lang} = $translation[1] if scalar(@translation) > 1;
				$found{$lang}++;
			}
		}
	}
	elsif ($string_file =~ /\.iss/i) {
		while(<STRINGS>) {
	
			# remove newline chars and trailing tabs/spaces
			chomp; s/[\t\s]+$//; 

			next unless /([a-z]{2})\.(\w+?)=(.*)/i;
			(my $lang, my $string, my $translation) = (uc($1), $2, $3);

			if (!$DATA{'data'}{$string_file}{$string}) {
				# add {FILE}{STRING} to %DATA, with blanks for all supported langs
				for my $lang (@$supported_langs) {
					$DATA{'data'}{$string_file}{$string}{$lang} = "";
					map { $missing{$_}++ } @$supported_langs;
				}				
			}

			$DATA{'data'}{$string_file}{$string}{$lang} = $translation;

			$found{$lang}++;
		}		
	}

	close(STRINGS);
	for my $lang (@$supported_langs) {
		$DATA{'usefile'}{$string_file}{$lang}++;
	}
}


if ($args->{'format'} =~ /(xml|slt)/) {
	my $dir = "stringsFiles";
	mkdir $dir unless -d $dir;
	for my $LANG (@$supported_langs) {
		# SLT team wants EN as well
		#next if $LANG eq 'EN';
		next if $found{$LANG} == $missing{$LANG};
		my $template = 'strings.' . $args->{'format'} . '.tmpl';
		my $outfile  = $dir . "/$args->{'filename'}-" . $LANG . "." . ($args->{'format'} eq 'slt' ? 'txt' : $args->{'format'});
		print "Creating $outfile\n";
		my $tt = Template->new({ EVAL_PERL => 1 });
		$tt->process($template, { data => \%DATA , target => $LANG }, $outfile) || die $tt->error;
	}
} else {
	my $template = 'strings.' . $args->{'format'} . '.tmpl';
	my $outfile  = "strings." . $args->{'format'};
	my $tt = Template->new;
	$tt->process($template, { data => \%DATA }, $outfile) || die $tt->error;
}

exit 1;

sub get_strings_files {
	my @return;
	find sub {
		my $file = $File::Find::name;
		push @return, $file if $file =~ /strings\.(txt|iss)$/;
	}, @$dirs;
	return \@return;
}

sub command_args {
	my %args;
	my $usage = "usage: find_translations_todo.pl (--verbose) (--format [xml|slt|txt]) (--dirs '...') (--langs '...')
	--format defaults to txt. xml is the other option.
	--verbose prints file information on each line
	argument to --dirs is a list of dirs to search 
		(defaults to '.')
	argument to --langs is a list of languages to check for translation 
		(defaults to @default_supported_langs)\n";
	GetOptions(
		'help'       => \$args{'help'},
		'dirs=s'     => \$args{'dirstring'},
		'langs=s'    => \$args{'langstring'},
		'format=s'   => \$args{'format'},
		'verbose'    => \$args{'verbose'},
		'filename=s' => \$args{'filename'},
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

	$args{'format'} eq 'txt' unless $args{'format'};

	my @langs = @default_supported_langs;
	if ($args{'langstring'}) {
		@langs = split/[^A-Z]+/, $args{'langstring'};
	}
	$args{'langs'} = \@langs;

	return \%args;
}
