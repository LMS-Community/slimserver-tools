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
use Data::Dump qw(dump);
use utf8;
use Getopt::Long;
use Template;

my @default_supported_langs = qw/ EN CS DA DE ES FI IT FR NL NO PL RU SV /;
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
	print "Reading $string_file\n";
	open(STRINGS, "<$string_file") or die "$!";
	my $string;

	if ($string_file =~ /\.txt$/i) {
		while(<STRINGS>) {
	
			# remove newline chars and trailing tabs/spaces
			chomp; s/[\t\s]+$//; 
	
			# this is a STRING ID
			if (/^[A-Z0-9]/) {
				$string = $_;
				# add {FILE}{STRING} to %DATA, with blanks for all supported langs
				for my $lang (@$supported_langs) {
					$DATA{'data'}{$string_file}{$string}{$lang} = "";
					delete $DATA{'data'}{$string_file}{$string}{SLT};
					map { $missing{$_}++ } @$supported_langs;
				}
			}
	
			# this is a TRANSLATION
			elsif ($string ne "" && /^[\t\s]+[A-Z][A-Z]/) {
				next if $args->{filter} && $string !~ /$args->{filter}/i;
				s/^[\t|\s]+//;
				my ($lang, @translation) = split /[\t]+/;
				$DATA{'data'}{$string_file}{$string}{$lang} = $translation[0];
				$DATA{'comment'}{$string_file}{$string}{$lang} = $translation[1] if scalar(@translation) > 1;
				$found{$lang}++;
			}
			
			# this is a comment for the translators
			elsif ($string ne "" && /^#\s*SLT[\s:]+(.*)/si) {
				$DATA{'data'}{$string_file}{$string}{SLT} ||= '';
				$DATA{'data'}{$string_file}{$string}{SLT} .= $1;
			}
			
		}
	}
	elsif ($string_file =~ /\.iss/i) {
		while(<STRINGS>) {
	
			# remove newline chars and trailing tabs/spaces
			chomp; s/[\t\s]+$//; 

			next unless /([a-z]{2})\.(\w+?)=(.*)/i;
			(my $lang, my $string, my $translation) = (uc($1), $2, $3);
			$lang =~ s/CZ/CS/i;

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
	elsif ($string_file =~ /\.json/i) {
		require File::Slurp;
		require JSON::XS;

		my $strings = File::Slurp::read_file($string_file);
		utf8::encode($strings);
		
		$DATA{'data'}{$string_file} = eval {
			JSON::XS::decode_json( $strings )
		} || die $@;
		
		map { $found{$_} = 1 } @{ $DATA{langs} };
	}

	close(STRINGS);
	for my $lang (@$supported_langs) {
		$DATA{'usefile'}{$string_file}{$lang}++;
	}
}


if ($args->{'format'} =~ /(xml|slt)/) {
	my $dir = $args->{product};
	mkdir $dir unless -d $dir;
	
	for my $LANG (@$supported_langs) {
		# SLT team wants EN as well
		#next if $LANG eq 'EN';
		next if $found{$LANG} == $missing{$LANG};
		my $template = 'strings.' . $args->{'format'} . '.tmpl';
		my $outfile  = $dir . "/$args->{product}-$LANG." . ($args->{'format'} eq 'slt' ? 'txt' : $args->{'format'});
		print "Creating $outfile\n";
		
		my $content = "";
		my $tt = Template->new({ EVAL_PERL => 1, ENCODING => 'utf8' });
		$tt->process($template, { data => \%DATA , target => $LANG }, \$content) || die $tt->error;
		
		open(STRINGS, ">:raw", $outfile) or die "Couldn't open $outfile for writing: $!\n";
		print STRINGS "\x{FEFF}";		# insert BOM
		binmode STRINGS;
		print STRINGS $content;
		close(STRINGS);
	}
}

elsif ($args->{'format'} eq 'txt') {
	my $template = 'strings.' . $args->{'format'} . '.tmpl';
	my $outfile  = "strings." . $args->{'format'};
	my $tt = Template->new;
	$tt->process($template, { data => \%DATA }, $outfile) || die $tt->error;
}

# print a list of missing translations
else {
	foreach my $file (@{$DATA{files}}) {
		
		foreach my $token (keys %{ $DATA{data}->{$file} }) {
			
			# we're not interested in _DBL tokens
			next if $token =~ /_DBL$/;

			my @missing_languages;

			foreach my $lang (@{$DATA{langs}}) {
				if (! $DATA{data}->{$file}->{$token}->{$lang}) {
					push @missing_languages, $lang;
					delete $DATA{data}->{$file}->{$token}->{$lang};
				}
			}

			if (scalar @missing_languages) {
				my $original = $DATA{data}->{$file}->{$token}->{EN};
				my $original_language = 'EN';
				
				if (!$original) {
					my @existing = keys %{ $DATA{data}->{$file}->{$token} };
					$original_language = $existing[0];
					$original = $DATA{data}->{$file}->{$token}->{ $existing[0] };
				}

				if ($original) {
					print "$file: $token\n$original_language: $original\nmissing: " . join(', ', @missing_languages) . "\n\n";
				}
			}
		}
	}
}

exit 1;

sub get_strings_files {
	my @return;
	find sub {
		my $file = $File::Find::name;
		my $path = $File::Find::dir;

		if ($file =~ /strings\.(txt|iss|json)$/ 
			&& $path !~ /\.svn/
			&& $path !~ /SqueezePlay\.app/
			&& $path !~ /Plugins/
			&& $file !~ /slimservice-strings.txt/
			&& $path !~ /slimserver-strings/) {
				
			push @return, $file;
		}
	}, @$dirs;
	return \@return;
}

sub command_args {
	my %args;
	my $usage = "usage: find_translations_todo.pl (--verbose) (--format [xml|slt|txt]) (--dirs '...') (--langs '...') (--product '...') (--filter '...')
	--format which output format you want
	--verbose prints file information on each line
	--filter if you only want strings with a matching ID (regex)
	
	argument to --dirs is a list of dirs to search 
		(defaults to '.')
	argument to --langs is a list of languages to check for translation 
		(defaults to @default_supported_langs)

	If no --format is defined, the script will print a list of strings
	for which one or more translations are missing\n";
		
	GetOptions(
		'help'       => \$args{'help'},
		'dirs=s'     => \$args{'dirstring'},
		'langs=s'    => \$args{'langstring'},
		'format=s'   => \$args{'format'},
		'verbose'    => \$args{'verbose'},
		'product=s'  => \$args{'product'},
		'filter=s'   => \$args{'filter'},
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

	$args{'format'} = 'slt' unless $args{'format'};

	my @langs = @default_supported_langs;
	if ($args{'langstring'}) {
		@langs = split/[^A-Z]+/, $args{'langstring'};
	}
	$args{'langs'} = \@langs;

	$args{product} ||= 'strings';

	return \%args;
}
