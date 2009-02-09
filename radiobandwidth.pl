#!/usr/bin/perl
#
# $Id$
#
# This script connects to a radio station for 60 seconds (by default)
# and produces a graph of the data bandwidth sent by the stream.
# It is useful for checking stream burst size and overall stream health.

use strict;

$|++;

use Data::Dump qw(dump);
use HTTP::Request;
use List::Util qw(min max);
use LWP::UserAgent;
use Tie::IxHash;
use Time::HiRes qw(time);
use URI::Escape qw(uri_escape_utf8);

tie my %stats, 'Tie::IxHash', ();
my $bitrate = '?';

my $ua = LWP::UserAgent->new(
	agent   => 'Winamp/5.0',
	timeout => 10,
);

my $url = shift || die "Usage: $0 URL [duration]\n";
my $dur = shift || 60;

my $req = HTTP::Request->new( GET => $url );
$req->header( 'Icy-Metadata' => 1 );

my $start = int( time() );

my $res = $ua->request( $req, \&content, 1024 );

if ( !$res->is_success ) {
	warn "Error: " . $res->status_line . "\n";
}
else {
	# Determine bitrate
	if ( my $ai = $res->header('ice-audio-info') ) {
		($bitrate) = $ai =~ /ice-bitrate=([^;]+)/;
	}
	
	if ( !$bitrate ) {
		if ( my $br = $res->header('icy-br') ) {
			if ( ref $br eq 'ARRAY' ) {
				$bitrate = $br->[0];
			}
			else {
				$bitrate = $br;
			}
		}
	}

	if ( !$bitrate ) {
		warn dump($res->headers) . "\n";
	}

	# Google chart it
	my @data = map { sprintf("%d", $_) } values %stats;
	
	# Hide passwords
	if ( $url =~ m{http://[^:]+:([^@]+)@} ) {
		$url =~ s/$1/xxxx/g;
	}
	
	my $title = "$url ($bitrate";
	if ( $bitrate =~ /^\d+$/ ) {
		$title .= " kbps)";
	}
	else {
		$title .= ")";
	}

	my $chart = "http://chart.apis.google.com/chart?cht=lc&chs=500x250&chtt=" . uri_escape_utf8($title) . "&chd=t:";

	# Data set 1
	$chart .= join(',', @data);

	# Min/max scaling
	$chart .= '&chds=' . join( ',', min(@data) - 4, max(@data) + 4 );

	# Axis type & range
	$chart .= '&chxt=x,y,x,y&chxr=0,1,' . scalar(@data) . '|1,' . (min(@data) - 4) . ',' . (max(@data) + 4);
	
	# Axis labels
	$chart .= '&chxl=2:|Seconds|3:|KBytes';
	$chart .= '&chxp=2,50|3,50';
	
	# Data point labels
	$chart .= '&chm=N,FF0000,0,-3,10,-1';

	print $chart . "\n";
	
	# Save image
	$ua->get( $chart, ':content_file' => 'output.png' );
	print "Saved as output.png\n";
}

sub content {
	my ( $data, $res, $prot ) = @_;
	
	my $ts = int( time() );
	
	if ( $ts - $start > $dur ) {
		print "\n";
		die "End";
	}
	
	$stats{$ts} += length($data) / 1024;
	
	print '.';
}
