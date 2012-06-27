#!/usr/bin/perl

use strict;
use File::Find;
use Data::Dump qw(dump);
use Getopt::Long;

# some string tokens can't be found because they are concatenated at run time
# ignore them in the search
use constant CONCATENATED_TOKENS => qw(
	WELCOME_TO_.+
	WIMP_GENRE_.+
	
); 

my $stringDirs;
my $sourceDirs;
my $doDaDupes = 0;
my $tokenFilter;

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

$tokenFilter = qr/.*$tokenFilter.*/ if $tokenFilter;

print "\nFinding string tokens...\n";

for my $file (@$stringsFiles) {
#	print "Reading $file\n";
	open(STRINGS, "<$file") or die "$!";

	while(<STRINGS>) {
		# remove newline chars and trailing tabs/spaces
		chomp; s/[\t\s]+$//;

		next if $tokenFilter && $_ !~ $tokenFilter;

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

if (!keys %stringTokens) {
	print "\nDidn't find any string tokens - aborting.\n";
	exit;
}

if ($doDaDupes) {
	print "\nFinding duplicates...\n";
	foreach (grep { $stringTokens{$_} > 1 } keys %stringTokens) {
		print "\n$_:\n", join("\n", @{$dupes{$_}}) . "\n";
	}
}

print "\nCreating dictionary of potential source code matches...\n";
my %sourceLines;

open SC, "ack --perl --html --lua --tt --nosmart-case -oh \"\\b[A-Z][A-Z_\\d]{2,}\\b\" $sourceDirs |";
while (<SC>) {
	# remove newline chars and trailing tabs/spaces
	chomp; s/[\t\s]+$//; 

	$sourceLines{$_}++;
}
print "Found " . scalar(keys %sourceLines) . " candidates\n";

if (!keys %sourceLines) {
	print "\nDidn't find any candidates in source code files - aborting.\n";
	exit;
}

print "\nFinding potentially unused string tokens...\n";
my $ignoreRegex = join('|', CONCATENATED_TOKENS);
$ignoreRegex = qr/(?:$ignoreRegex)/;
foreach (keys %stringTokens) {
	# remove tokens which were found
	if ($sourceLines{$_}) {
		delete $stringTokens{$_};
		delete $sourceLines{$_};     # thanks - we no longer need you
	}
	
	delete $stringTokens{$_} if $_ =~ $ignoreRegex;
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
		'filter=s'     => \$tokenFilter,
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