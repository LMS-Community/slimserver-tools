#!/usr/bin/perl -w

# SqueezeCenter Copyright (C) 2003-2004 Logitech.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

#
# Command line interface for the controlling the SqueezeCenter
#

use strict;
use Getopt::Long;
use LWP::Simple;


sub main {
	my $httpaddr = undef;
	my $httpport = undef;
	my $player = undef;
	my $command = undef;
	my $p1 = undef;
	my $p2 = undef;
	my $p3 = undef;
	my $p4 = undef;

	GetOptions(
		'httpaddr=s'	=> \$httpaddr,
		'httpport=s'	=> \$httpport,
		'player=s'	=> \$player,
		'command=s'	=> \$command,
		'p1=s'		=> \$p1,
		'p2=s'		=> \$p2,
		'p3=s'		=> \$p3,
		'p4=s'		=> \$p4,
	);

	
	if ( (!defined($command)) || 
	     (!defined($httpaddr)) || 
	     (!defined($httpport)) ) {
		showUsage();
	}
	else {
		executeCommand($httpaddr, $httpport, $player, $command, $p1, $p2, $p3, $p4);
	}

} # end sub main

	# Commands are extracted from the parameters p0, p1, p2, p3, & p4.
	#   For example:
	#       http://host/status.html?p0=stop
	# Both examples above execute a stop command, and sends an html status response
	#
	# Command parameters are query parameters named p0, p1, p2, p3 and p4
	# 	For example:
	#		http://host/status.m3u?p0=playlist&p1=jump&p2=2 
	# This example jumps to the second song in the playlist and sends a playlist as the response
	#
	# If there are multiple players, then they are specified by the player id
	#   For example:
	#		http://host/status.html?p0=mixer&p1=volume&p2=11&player=10.0.1.203:69
	#
sub executeCommand {
    my ($httpaddr, $httpport, $player, $command, $p1, $p2, $p3, $p4) = @_;
    my $urlstring = undef;
	my $content = undef;
	
	$urlstring = "http://$httpaddr:$httpport/status?p0=$command";

    if ( defined($p1) ) {
        $p1 =~s/([^a-zA-Z0-9_\-.])/uc sprintf("%%%02x",ord($1))/eg;
            $urlstring .= "&p1=" . $p1;
    }

    if ( defined($p2) ) {
        $p2 =~s/([^a-zA-Z0-9_\-.])/uc sprintf("%%%02x",ord($1))/eg;
            $urlstring .= "&p2=" . $p2;
    }

    if ( defined($p3) ) {
        $p3 =~s/([^a-zA-Z0-9_\-.])/uc sprintf("%%%02x",ord($1))/eg;
            $urlstring .= "&p3=" . $p3;
    }

    if ( defined($p4) ) {
        $p4 =~s/([^a-zA-Z0-9_\-.])/uc sprintf("%%%02x",ord($1))/eg;
            $urlstring .= "&p4=" . $p4;
    }

	$urlstring .= "\n";
	unless (defined ($content = get($urlstring))) {
    		die "could not get $urlstring\n";
	}

	print $urlstring, "\n";

	
} # end sub executeCommand


sub showUsage {

        print <<EOF;
Usage: $0 --httpaddr <host|ip> --httpport <port> --command <command> 
          [--p1 <arg>] [--p2 <arg>] [--p3 <arg>] [--p4 <arg>] [--player <playerid>]

        --httpaddr  => The hostname or ip address of the Slim web server
	--httpport  => The port on which the Slim web server is listening
	--command   => Pick from the 1st column of the list below
        --p1        => Pick from the 2st column of the list below
        --p2        => Pick from the 3rd column of the list below
        --p3        => Pick from the 4th column of the list below
        --p4        => Pick from the 5th column of the list below
        --player    => Currently the "ip:port" of your player

	COMMAND		P1	P2		P3	P4
	 play
	 pause		(0|1|)
	 stop
	 sleep		(0..n)
	 playlist	play    <song>
	 playlist	load    <playlist>
	 playlist	append  <playlist>
	 playlist	clear
	 playlist	move    <fromoffset>	<tooffset>
	 playlist	delete  <songoffset>
	 playlist	jump    <index>
	 mixer		volume  (0 .. 100)|(-100 .. +100)
	 mixer		balance (-100 .. 100)|(-200 .. +200)
	 mixer		base    (0 .. 100)|(-100 .. +100)
	 mixer		treble  (0 .. 100)|(-100 .. +100)
	 status
	 display	<line1> <line2>		(duration)
EOF

} # end sub showUsage

main();

