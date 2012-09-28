#!/usr/bin/perl

use strict;
use File::Find;
use Data::Dump qw(dump);
use Getopt::Long;

use constant CONCATENATED_TOKENS => [
	WIMP_GENRE_.+
]; 

my $stringDirs;
my $sourceDirs;
my $doDaDupes = 0;

if (!`ack`) {
	print "\nI'm sorry, I'm the lazy guy. This scripts uses ack (http://betterthangrep.com/)\nto do the heavy lifting. But this nifty tool is not installed on your system.\n\n";
	exit;
}

getArgs();

print "\nFinding strings files...\n";
my $stringsFiles = getStringsFiles();
print "Found " . scalar @$stringsFiles . " strings files\n";

my %stringTokens;
my %dupes;

print "\nFinding string tokens...\n";
for my $file (@$stringsFiles) {
#	print "Reading $file\n";
	open(STRINGS, "<$file") or die "$!";

	while(<STRINGS>) {
		# remove newline chars and trailing tabs/spaces
		chomp; s/[\t\s]+$//; 

		# this is a STRING ID
		if (/^[A-Z0-9]/) {
			$stringTokens{$_}++;
			$dupes{$_} ||= [];
			push @{$dupes{$_}}, $file;
		}
	}

	close(STRINGS);
}
print "Found " . (keys %stringTokens) . " string tokens\n";

if ($doDaDupes) {
	print "\nFinding duplicates...\n";
	foreach (grep { $stringTokens{$_} > 1 } keys %stringTokens) {
		print "\n$_:\n", join("\n", @{$dupes{$_}}) . "\n";
	}
}

print "\nCreating dictionary of potential source code matches...\n";
my %sourceLines;

open SC, "ack --perl --html --lua --nosmart-case -oh \"\\b[A-Z][A-Z_\\d]{2,}\\b\" $sourceDirs |";
while (<SC>) {
	chomp;
	$sourceLines{$_}++;
}
print "Found " . (keys %sourceLines) . " candidates\n";

print "\nFinding potentially unused string tokens...\n";
foreach (keys %stringTokens) {
	# remove tokens which were found
	delete $stringTokens{$_} if $sourceLines{$_};
}

print join("\n", sort keys %stringTokens);

#print Data::Dump::dump(%stringTokens);


sub getStringsFiles {
	my @return;
	find({
		wanted => sub {
			my $file = $File::Find::name;
			my $path = $File::Find::dir;
	
			if ($file =~ /strings\.txt$/ 
				&& $path !~ /\.(?:svn|git)/
				&& $path !~ /Plugins/) {

				push @return, $file;
			}
		},
	}, @$stringDirs);
	return \@return;
}

sub getArgs {
	my $dirstring;

	GetOptions(
		'stringDirs=s' => \$dirstring,
		'sourceDirs=s' => \$sourceDirs,
		'dupes'        => \$doDaDupes,
	);
	
	# parse dirs by spaces 
	my @dirs = ( '.' );
	if ($dirstring) {
		@dirs = split/\s+/, $dirstring;
	}

	$stringDirs = \@dirs;
	
	$sourceDirs ||= '';
}

1;