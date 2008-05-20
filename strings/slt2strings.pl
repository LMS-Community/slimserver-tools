#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Data::Dumper;

my @default_supported_langs = qw/ EN DA DE ES FI IT FR NL NO SV /;
my %strings;

my $args = command_args();


foreach my $lang (@{$args->{'langs'}}) {
	my $fileName = "$args->{'product'}-$lang.txt";

	open(MYSTRINGS, "<:utf8", $fileName) or (warn "Couldn't open $fileName for reading: $!\n" && next);
	binmode MYSTRINGS;

	foreach (<MYSTRINGS>) {
	     chomp;
		if (/^(.*)__(.*?)\t(.*)$/) {
			$strings{$1}{$2}{$lang} = $3;
		}
	}
	close(MYSTRINGS);
}

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


sub command_args {
	my %args;
	my $usage = "usage: slt2strings.pl (--langs '...') (--product '...')
	argument to --langs is a list of languages to check for translation 
		(defaults to @default_supported_langs)
	argument to --product is a product id such as string (default SC strings), squeezetray, squeezenetwork or firmware 
		(defaults to strings)\n";

	GetOptions(
		'help'	=>	\$args{'help'},
		'langs=s'	=>	\$args{'langstring'},
		'product=s' =>  \$args{'product'},
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

	$args{'product'} ||= 'strings';

	return \%args;
}

1;

