#!/usr/bin/perl
#
# Dump the keys of SlimServer's FileCache to a text file
#

$| = 1;

use strict;
use warnings;

use Cache::FileCache;
use File::Spec::Functions qw(catdir);
use Storable qw(nfreeze);

my $cacheDir = shift || die qq{
Please specify the path to your SlimServer Cache directory.

Examples: 
  Win: C:/Program Files/SlimServer/server/Cache
  Mac: ~/Library/Caches/SlimServer

};

if ( !-d catdir($cacheDir, 'FileCache') ) {
	die "Directory $cacheDir does not seem to contain a FileCache directory.\n";
}

my $cache = Cache::FileCache->new( {
	namespace           => 'FileCache',
	cache_root          => $cacheDir,
	directory_umask     => umask(),
	auto_purge_interval => '1 hour',
} );

print "Writing cache keys to file: cachedump.txt...\n";

open my $fh, '>', 'cachedump.txt';

my $count = 0;

for my $key ( $cache->get_keys() ) {
	if ( my $data = $cache->get($key) ) {
		my $size = ( ref $data ) ? length( nfreeze($data) ) : length($data);
		print $fh sprintf( "%8d   %s\n", $size, $key );
		$count++;
	}
}

close $fh;

print "Wrote $count keys to cachedump.txt\n";