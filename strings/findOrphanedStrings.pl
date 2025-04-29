#!/usr/bin/perl

use strict;
use File::Find;
use Data::Dump qw(dump);
use Getopt::Long;

# some string tokens can't be found because they are concatenated at run time
# ignore them in the search
use constant CONCATENATED_TOKENS => qw(
	DEBUG_.+
	.+_MUSIC_PLAYER
	NAPSTER_ERROR_\d+
	PLUGIN_RANDOM.*(?:WEB|DISABLE|ITEM|PLAYING)
	PLUGIN_FAVORITES_.*(?:ERROR|NO[A-Z]+)$
	PLUGIN_SOUNDS_.*
	^RADIOTIME_[LMNPSTW].*
	PLUGIN_EXTENDED_BROWSEMODES_.*
	SETUP_EXTENSIONS_CATEGORY_.*
	SETUP_EXTENSIONS_AUTHOR
	SETUP_EXTENSIONS_OTHER_REPOSITORIES
	SETUP_EXTENSIONS_RECOMMENDED_REPOSITORIES
	PLUGIN_RSSNEWS_.*
	PLUGIN_SCREENSAVER_SNOW_WORD_.*
	PLUGIN.*_MISSING_CREDS
	SETUP_DEFEAT_DESTRUCTIVE_TTP_.*
	SPOTIFY_ERROR_\d+
	TZ_.+
	UPDATING_FIRMWARE_.+
	WELCOME_TO_.+
	WIMP_GENRE_.+
	ALARM_SHORT_DAY_\d
	[A-Z0-9_]+_PROGRESS
	DECODE_ERROR_\d+
	RELEASE_TYPE_.+
	[A-Z0-9_]+_SKIN
);

use constant SOURCE_CACHE => 'sourceCache.bin';

my $stringDirs;
my $sourceDirs;
my $doDaDupes = 0;
my $tokenFilter;
my $cacheSourceData;

getArgs();

# only try to load Storable if we want to cache
# don't try to cache if Storable can't be loaded
if ($cacheSourceData) {
	eval {
		require Storable;
	};

	$cacheSourceData = 0 if $@;
}

if (!`ack`) {
	print "\nI'm sorry, I'm the lazy guy. This scripts uses ack (http://betterthangrep.com/)\nto do the heavy lifting. But this nifty tool is not installed on your system.\n\n";
	exit;
}

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
	my $i = 0;
	foreach (grep { $stringTokens{$_} > 1 } keys %stringTokens) {
		$i++;
		print "\n$_:\n", join("\n", @{$dupes{$_}}) . "\n";
	}
	print "Found $i duplicates\n";
}

print "\nCreating dictionary of potential source code matches...\n";
my %sourceLines;

if ($cacheSourceData) {
	eval {
		%sourceLines = %{ Storable::retrieve(SOURCE_CACHE) };

		if ($sourceLines{_cache_key} && $sourceLines{_cache_key} ne $sourceDirs) {
			%sourceLines = ();
		}
		else {
			print "Using cached dictionary.\n";
		}
	};
}
else {
	unlink SOURCE_CACHE;
}

if (!keys %sourceLines) {
	open SC, "ack --perl --html --lua --tt --xml --nosmart-case -oh \"\\b[A-Z][A-Z_\\d]{2,}\\b\" $sourceDirs |";
	while (<SC>) {
		# remove newline chars and trailing tabs/spaces
		chomp; s/[\t\s]+$//;

		$sourceLines{$_}++;
	}
}

if ($cacheSourceData && keys %sourceLines) {
	$sourceLines{_cache_key} = $sourceDirs;
	Storable::store(\%sourceLines, SOURCE_CACHE);
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
print "\n\nFound " . scalar(keys %stringTokens) . " unused strings\n";

sub getStringsFiles {
	my @return;
	find({
		wanted => sub {
			my $file = $File::Find::name;
			my $path = $File::Find::dir;

			if ($file =~ /strings\.txt$/
				&& $path !~ /\.(?:svn|git)/
#				&& $path !~ /slimserver-strings/
				&& $path !~ /Plugins/) {

				push @return, $file;
			}
		},
	}, @$stringDirs);
	return \@return;
}

sub getArgs {
	my $dirstring;
	my $help;

	GetOptions(
		'help'         => \$help,
		'stringDirs=s' => \$dirstring,
		'sourceDirs=s' => \$sourceDirs,
		'dupes'        => \$doDaDupes,
		'filter=s'     => \$tokenFilter,
		'cache'        => \$cacheSourceData,
	);

	if ($help || !$dirstring || !$sourceDirs) {
		print "
usage: $0 --stringDirs '...' --sourceDirs '...' (--dupes) (--cache) (--filter '...')
   stringDirs - a space separated list of folders which will be recursively searched for strings files
   sourceDirs - a space separated list of folders with our source files
   dupes      - print a list of duplicate string definitions
   filter     - a regex to be used to filter the resulting token list
   cache      - cache dictionary of potential string tokens found in the source code

PLEASE NOTE: do NOT blindly trust the resulting list. As sometimes string tokens are concatenated
             and processed in other ways, the static search is likely to fail in many ways.

This scripts uses ack (http://betterthangrep.com/) to do the heavy lifting. Make sure it's installed
on your system and can be found in the default paths.

";
		exit;
	}

	# parse dirs by spaces
	my @dirs = ( '.' );
	if ($dirstring) {
		@dirs = split/\s+/, $dirstring;
	}

	$stringDirs = \@dirs;

	$sourceDirs ||= '';
}

1;