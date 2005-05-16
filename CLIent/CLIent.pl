#!/usr/bin/perl -w

# ********************************************************************
# CLI Exerciser N' Tester                                    v0.2
#
# Copyright (c) 2005 Frederic Thomas (fred(at)thomascorner.com)
#
# This file might be distributed under the same terms as the
# Slimserver (www.slimdevices.com)
#
# Description:
# Tests and exercises the CLI
#
# Plattform tested:
# - MacOS X 10.3.x
#
# Known restrictions:
#
# History:
# 0.1 - Inital version for CLI in SlimServer 5.4.1
# 0.2 - For CLI in SlimServer 6.0.x
# ********************************************************************


#TODO (Check WARNING)
# display ? ?
# listen
# playlist search


use strict;
use Getopt::Long;
use IO::Socket;
use Test::More 'no_plan';
use IO::Socket qw(:DEFAULT :crlf);
use URI::Escape;
use POSIX qw(ceil);


# Parameter defaults overridden by command line
my $szServerIP		= "127.0.0.1";
my $iServerCLIPort	= 9090;
my $sSkip           = '';

# Internal parameters
my $debug		= 1;	# 0 = off, 1 = on


# Globals
my @players;
my %database;
my %playlists;

my $songsCount; 
my $playersCount;

my $searchSubStringPref;

# Any command line options?
GetOptions( 	"server:s"	=>	\$szServerIP,
				"port:i"	=>	\$iServerCLIPort,
				"skip:s"	=>	\$sSkip);


print "\nSlimServer CLI Exerciser N' Tester 0.2\n\n";

showUsage();

print "\nSkipping: $sSkip\n\n";

showTestTitle("Connecting to SlimServer");

# Try to open a connection to the Slimserver CLI
my $socket = IO::Socket::INET->new(	PeerAddr => $szServerIP, PeerPort => $iServerCLIPort, Proto => "tcp", Type => SOCK_STREAM);

# First test, can we connect?
ok(defined($socket), "connected to $szServerIP:$iServerCLIPort");

if (defined $socket) {

	testsInit();
	
	playerCommandsTests() if !($sSkip =~ /p/);
	
	databaseCommandsTests() if !($sSkip =~ /d/);
	
	playlistCommandsTests() if !($sSkip =~ /l/);
	
	generalCommandsTests() if !($sSkip =~ /g/);
	
	close($socket);
}

exit;



# ---------------------------------------------
# Subroutines
# ---------------------------------------------
sub testsInit
{
	#init our players...

	showTestTitle("Init tests");

	$playersCount = queryNum(undef, ['player', 'count']);
	for(my $i = 0; $i < $playersCount; $i++)
	{
		my $playerid = query(undef, ['player', 'id', "$i"]);
		$players[$i] = $playerid;
		cmd($playerid, ['power', 1]);
		cmd($playerid, ['sleep', 0]);
		cmd($playerid, ['stop']);
		cmd($playerid, ['playlist', 'clear']);
		cmd($playerid, ['playlist', 'shuffle', '0']);
		cmd($playerid, ['playlist', 'repeat', '0']);
	}
	
	if ($playersCount){
		print("INFO: Turned all $playersCount players on, no sleep, stopped, clear playlist, no repeat, no shuffle...\n\n");
		sleep 3;
	} else {
		print("WARNING: No players. Some tests will be skipped!\n\n");
	}
	
	$songsCount = queryNum(undef, ['info', 'total', 'songs']);
	
	if ($songsCount){
		print("INFO: $songsCount songs in database...\n\n");
		sleep 3;
	} else {
		print("WARNING: No songs. Some tests will be skipped!\n\n");
	}
	
	# Set searchSubString pref to on as this is what our code expect
	# Remember user preference and restore in generalCommandsTests
	$searchSubStringPref = queryFlag(undef, ['pref', 'searchSubString']);
	cmd(undef, ['pref', 'searchSubString', 1]);
}

# ---------------------------------------------
sub generalCommandsTests
{
	showTestTitle("Testing general commands, including exit");

	testFlag(undef, ['debug', 'd_command']);
	
	testFlag(undef, ['pref', 'composerInArtists']);
	
	# Restore changed preferences...
	
	cmd(undef, ['pref', 'searchSubString', $searchSubStringPref]);
	
	
#	testFlag(undef, ['listen']);

	sendCmd(undef, ['exit']);
	ok(!defined(sendCmd(undef, ['exit'])), "exit ok");
}


# ---------------------------------------------
sub playerCommandsTests
{
	
	my %playersData;
	my %playersData_players;
	my %playersIdx;
	my @players_players;
	
	my @softsqueezes;
	my @squeezeboxen;
	my @sliMP3s;

	showTestTitle("Testing [player] queries");

	my $numPlayers = queryNum(undef, ['player', 'count']);
	$playersData{'player count'} = $numPlayers;

	SKIP: {
		skip('no players!') if !$numPlayers;
		
		for(my $i = 0; $i < $numPlayers; $i++)
		{
			my $playerid = query(undef, ['player', 'id', "$i"]);
			my $unique = 1;
			for(my $j=0; $j < $i; $j++)
			{
				$unique = $unique && ($players[$j] ne $players[$i]);
			}
			ok($unique, "player id is unique");
			$playersIdx{$playerid} = $i;
			
			$playersData{"player name $i"} = query(undef, ['player', 'name', "$i"]);
			
			my $playerip = query(undef, ['player', 'ip', "$i"]);
			$playersData{"player ip $i"} = $playerip;
			ok($playerip =~ /([^:]+):(.*)/, "query returns [$playerip], address; $1, port: $2");
			
			my $playermodel = query(undef, ['player', 'model', "$i"]);
			ok($playermodel eq "squeezebox" || $playermodel eq "slimp3" || $playermodel eq "softsqueeze", "query returns [$playermodel], one of softsqueeze, slimp3 or squeezebox");
			$playersData{"player model $i"} = $playermodel;
			
			if($playermodel eq "squeezebox") { push @squeezeboxen, $playerid;}
			if($playermodel eq "slimp3") { push @sliMP3s, $playerid;}
			if($playermodel eq "softsqueeze") { push @softsqueezes, $playerid;}
			
			
			my $playerdisp = query(undef, ["player", "displaytype", "$i"]);
			ok($playerdisp=~ /^graphic-/ || $playerdisp=~ /^noritake-/, "query returns [$playerdisp], starts with graphic- or noritake-");
			$playersData{"player displaytype $i"} = $playerdisp;
			
			#test we can use the player id and get the same data...
			ok($players[$i] eq query(undef, ['player', 'id', "$playerid"]), "[player id $playerid ?] returns the same as [player id $i ?]");
			ok($playersData{"player name $i"} eq query(undef, ['player', 'name', "$playerid"]), "[player name $playerid ?] returns the same as [player name $i ?]");
			ok($playersData{"player ip $i"} eq query(undef, ['player', 'ip', "$playerid"]), "[player ip $playerid ?] returns the same as [player ip $i ?]");
			ok($playersData{"player model $i"} eq query(undef, ['player', 'model', "$playerid"]), "[player model $playerid ?] returns the same as [player model $i ?]");
			ok($playersData{"player displaytype $i"} eq query(undef, ['player', 'displaytype', "$playerid"]), "[player displaytype $playerid ?] returns the same as [player displaytype $i ?]");
		
			#test sleep info
			$playersData{"sleep $i"} = queryNum($playerid, ['sleep']);
			
			$playersData{"sync $i"} = query_Sync($playerid, ['sync']);
			$playersData{"power $i"} = queryFlag($playerid, ['power']);
			$playersData{"signalstrength $i"} = queryNum($playerid, ['signalstrength']);
			$playersData{"connected $i"} = queryFlag($playerid, ['connected']);
			$playersData{"mixer volume $i"} = queryNum($playerid, ['mixer', 'volume']);
			$playersData{"mixer bass $i"} = queryNum($playerid, ['mixer', 'bass']);
			$playersData{"mixer treble $i"} = queryNum($playerid, ['mixer', 'treble']);
			$playersData{"mixer pitch $i"} = queryNum($playerid, ['mixer', 'pitch']);
			$playersData{"rate $i"} = queryNum($playerid, ['rate']);
			$playersData{"linesperscreen $i"} = queryNum($playerid, ['linesperscreen']);
			$playersData{"playerpref powerOnBrightness $i"} = queryNum($playerid, ['playerpref', 'powerOnBrightness']);
		
			query_dual($playerid, ['display']);
			query_dual($playerid, ['displaynow']);
		}		
		print("\n** Found $numPlayers players: " . scalar @sliMP3s . " SliMP3s, " . scalar @softsqueezes . " SoftSqueezes and " . scalar @squeezeboxen . " SqueezeBoxen\n");
	}

	showTestTitle("Testing [players] query");

	#my $totitems = $numPlayers;
	my $done = 0;
	my $curitem;
	my $once = 1;
	
	while (($done < $numPlayers) || $once) {

		$once = 0;
		my $from = $done;
		my $items = ceil(rand ($numPlayers - $done));
		if($items < 1) {
			$items = 1;
		}
		
		my @results = eCLIquery(undef, ['players', $from, $items]);

		for(my $i = 3; $i < scalar(@results); $i++){	
			$results[$i] =~ /([^:]+):(.*)/;
			
			if($1 eq 'count') {
				if($from == 0) {
					ok($2 == $numPlayers, "[players.count:] is the same as [player count ?]");
					#$totitems = $2;
				}
			} elsif ($1 eq 'playerindex') {
				$curitem = $2;
				$done++;
			} elsif ($1 eq 'playerid') {
				$players_players[$curitem] = $2;
			} elsif ($1 eq 'ip') {
				$playersData_players{"player ip $curitem"} = $2;
			} elsif ($1 eq 'name') {
				$playersData_players{"player name $curitem"} = $2;
			} elsif ($1 eq 'model') {
				$playersData_players{"player model $curitem"} = $2;
			} elsif ($1 eq 'displaytype') {
				$playersData_players{"player displaytype $curitem"} = $2;
			} elsif ($1 eq 'connected') {
				$playersData_players{"connected $curitem"} = $2;
			} else {
				ok(0, "[players] returns unknown tag: $1");
			}
		}
	}
    
    #now check the results of players match the results above
    for (my $i = 0; $i<$numPlayers; $i++) {
    	my $j = $playersIdx{$players_players[$i]};
    	ok(defined($j), "[players.$i.playerid:] was returned by [player id $j]");
 
		if(defined($playersData_players{"player ip $i"})) {
			ok($playersData_players{"player ip $i"} eq $playersData{"player ip $j"}, "[players.$i.ip:] matches [player ip $j]");
		}
		if(defined($playersData_players{"player name $curitem"})) {
			ok($playersData_players{"player name $i"} eq $playersData{"player name $j"}, "[players.$i.name:] matches [player name $j]");
		}		
		if(defined($playersData_players{"player model $curitem"})) {
			ok($playersData_players{"player model $i"} eq $playersData{"player model $j"}, "[players.$i.model:] matches [player model $j]");
		}
		if(defined($playersData_players{"player displaytype $curitem"})) {	
			ok($playersData_players{"player displaytype $i"} eq $playersData{"player displaytype $j"}, "[players.$i.displaytype:] matches [player displaytype $j]");
		}
		if(defined($playersData_players{"connected $curitem"})) {
			ok($playersData_players{"connected $i"} eq $playersData{"connected $j"}, "[players.$i.connected:] matches [$players_players[$i] connected ?]");
		}
    }
    
    
    
	showTestTitle("Testing [status 0 0] query");

    for (my $p = 0; $p<$numPlayers; $p++) {
    	my @results = eCLIquery($players_players[$p], ['status', 0, 0]);
		my $j = $playersIdx{$players_players[$p]};
		
		my $found_sigstrength = 0;
		my $found_sleep = 0;
	
		for(my $i = 4; $i < scalar(@results); $i++){	
			$results[$i] =~ /([^:]+):(.*)/;
			
			if ($1 eq 'player_name') {
				ok($2 eq $playersData{"player name $j"}, "[status.player_name:] matches [player name $j]");
			} elsif ($1 eq 'player_connected') {
				ok($2 eq $playersData{"connected $j"}, "[status.player_connected:] matches [$players_players[$p] connected ?]");
			} elsif ($1 eq 'power') {
				ok($2 eq $playersData{"power $j"}, "[status.power:] matches [$players_players[$p] power ?]");
			} elsif ($1 eq 'signalstrength') {
				#Only for Squeezeboxen
				ok($playersData{"player model $j"} eq "squeezebox", "[status.power:] reported for a squeezebox");
				ok($2 eq $playersData{"signalstrength $j"}, "[status.signalstrength:] matches [$players_players[$p] signalstrength ?]");
				$found_sigstrength = 1;
#If player is on: 	
			} elsif ($1 eq 'rate') { 	
				# Player rate. Only if there is a current song.
				ok($2 eq $playersData{"rate $j"}, "[status.rate:] matches [$players_players[$p] rate ?]");
			} elsif ($1 eq 'will_sleep_in') { 	#Minutes lefts until sleeping. Only if set to sleep.
				ok($2 eq $playersData{"sleep $j"}, "[status.will_sleep_in:] matches [$players_players[$p] sleep ?]");
				ok($playersData{"sleep $j"} ne "0", "[status.will_sleep_in:] reported since player is set to sleep");
				my $found_sleep = 1;
			} elsif ($1 eq 'mixer volume') {
				ok($2 eq $playersData{"mixer volume $j"}, "[status.mixer volume:] matches [$players_players[$p] mixer volume ?]");
			} elsif ($1 eq 'mixer treble') { 
				ok($2 eq $playersData{"mixer treble $j"}, "[status.mixer treble:] matches [$players_players[$p] mixer treble ?]");
			} elsif ($1 eq 'mixer bass') { 	
				ok($2 eq $playersData{"mixer bass $j"}, "[status.mixer bass:] matches [$players_players[$p] mixer bass ?]");
			} elsif ($1 eq 'mixer pitch') {
				ok($2 eq $playersData{"mixer pitch $j"}, "[status.mixer pitch:] matches [$players_players[$p] mixer pitch ?]");
				#Not for SliMP3 players.
			} elsif ($1 eq 'sleep') { 	#If set to sleep, the amount it was set to.
				#no equivalent...
			} elsif ($1 eq 'playlist repeat') { 	#0 no repeat, 1 repeat song, 2 repeat playlist.
			} elsif ($1 eq 'playlist shuffle') { 	#0 no shuffle, 1 shuffle songs, 2 shuffle albums.
			} elsif ($1 eq 'playlist_cur_index') { 	#Index (first is 0) of the current song in the playlist. Only if there is a playlist.
			} elsif ($1 eq 'playlist_tracks') {
			} elsif ($1 eq 'time') { 	#Elapsed time into the current song. Decimal seconds. Only if current song.
			} elsif ($1 eq 'duration') { 	#Duration of the current song. Decimal seconds. Only if current song.
			} elsif ($1 eq 'mode') { 	#Player mode.
			} elsif ($1 eq 'rescan') {  	#Returned with value 1 if the SlimServer is still scanning the database. The results may therefore be incomplete. Not returned if no scan is in progress.
			} else {
				ok(0, "[status] returns unknown tag: $1");
			}

			
		}
		ok(!$found_sleep && $playersData{"sleep $j"} eq "0", "[status.will_sleep_in:] not reported since player is not set to sleep");
		ok(!$found_sigstrength && $playersData{"player model $j"} ne "squeezebox", "[status.signalstrength:] not reported since player is not a squeezebox");	
	}	
	
	print("\n\nFinished testing player(s) queries!\n");
	sleep 3 if $numPlayers;

	# Now test player commands

	
	# power 
	# switch off all players and test using status and power ?
	
	showTestTitle("Testing power command");
	for(my $i = 0; $i < $numPlayers; $i++)
	{
		cmd($players[$i], ['power', 0]);
	}
	print("\n\nTurned all players off!\n");
	sleep 3;
	
	for(my $j = 0; $j < $numPlayers; $j++)
	{
		ok(queryFlag($players[$j], ['power']) eq "0", "[power ?] returns 0");
		my @results = eCLIquery($players[$j], ['status', 0, 0]);
		my $onlyPower = "";
		for(my $i = 4; $i < scalar(@results); $i++){	
			$results[$i] =~ /([^:]+):(.*)/;
			
			if ($1 eq 'power') {
				ok($2 eq "0", "[status.power:] returns 0");
			} elsif ($1 eq 'player_name') {
			} elsif ($1 eq 'player_connected') {
			} elsif ($1 eq 'signalstrength') {
#If player is on: 	
			} elsif ($1 eq 'rate') { 
				$onlyPower = $1;
			} elsif ($1 eq 'will_sleep_in') { 	#Minutes lefts until sleeping. Only if set to sleep.
				$onlyPower = $1;
			} elsif ($1 eq 'mixer volume') {
				$onlyPower = $1;
			} elsif ($1 eq 'mixer treble') {
				$onlyPower = $1;
			} elsif ($1 eq 'mixer bass') { 
				$onlyPower = $1;
			} elsif ($1 eq 'mixer pitch') {
				$onlyPower = $1;
			} elsif ($1 eq 'sleep') {
				$onlyPower = $1;
			} elsif ($1 eq 'playlist repeat') {
				$onlyPower = $1;
			} elsif ($1 eq 'playlist shuffle') {
				$onlyPower = $1;
			} elsif ($1 eq 'playlist_cur_index') {
				$onlyPower = $1;
			} elsif ($1 eq 'playlist_tracks') {
				$onlyPower = $1;
			} elsif ($1 eq 'time') {
				$onlyPower = $1;
			} elsif ($1 eq 'duration') {
				$onlyPower = $1;
			} elsif ($1 eq 'mode') {
				$onlyPower = $1;
			} elsif ($1 eq 'rescan') {  	#Returned with value 1 if the SlimServer is still scanning the database. The results may therefore be incomplete. Not returned if no scan is in progress.
			} else {
				ok(0, "[status] returns unknown tag: $1");
			}
		}
		ok($onlyPower eq "", "[status] returns no unwanted tags with power off");
	}
	
	print("\n\nDone testing with players off, turning them back on...\n");
	for(my $i = 0; $i < $numPlayers; $i++)
	{
		cmd($players[$i], ['power', 1]);
	}
	print("\n\nAll players on!\n");
	sleep 3 if $numPlayers;

	
	showTestTitle("Applying identical random configuration to all players");
	# calculate random test configuration
	my $sleep = 120 + ceil(rand 240);
	my $volume = 20 + ceil(rand 40);
	my $bass = ceil(rand(100));
	my $treble = ceil(rand(100));
	my $rate = ceil(rand(2));
	my $pitch= 80 + ceil(rand(40));
	
	
	for(my $i = 0; $i < $numPlayers; $i++)
	{
		cmd($players[$i], ['sleep', $sleep]);
		cmd($players[$i], ['mixer', 'volume', $volume]);
		cmd($players[$i], ['mixer', 'bass', $bass]);
		cmd($players[$i], ['mixer', 'treble', $treble]);
		cmd($players[$i], ['mixer', 'pitch', $pitch]);
		cmd($players[$i], ['rate', $rate]);
	}
	print("\n\nAll players with random config!\n");
	sleep 3 if $numPlayers;;
	
	for(my $j = 0; $j < $numPlayers; $j++)
	{
		my @results = eCLIquery($players[$j], ['status', 0, 0]);
		for(my $i = 4; $i < scalar(@results); $i++){	
			$results[$i] =~ /([^:]+):(.*)/;
			
			if ($1 eq 'power') {
				ok($2 eq "1", "[status.power:] returns 1");
			} elsif ($1 eq 'player_name') {
			} elsif ($1 eq 'player_connected') {
			} elsif ($1 eq 'signalstrength') {
#If player is on: 	
			} elsif ($1 eq 'rate') { 
				ok($2 eq $rate, "[status.rate:] returns $rate");
			} elsif ($1 eq 'will_sleep_in') { 	#Minutes lefts until sleeping. Only if set to sleep.
			} elsif ($1 eq 'mixer volume') {
				ok($2 eq $volume, "[status.mixer volume:] returns $volume");
			} elsif ($1 eq 'mixer treble') {
				ok($2 eq $treble, "[status.mixer treble:] returns $treble");
			} elsif ($1 eq 'mixer bass') { 
				ok($2 eq $bass, "[status.mixer bass:] returns $bass");
			} elsif ($1 eq 'mixer pitch') {
				ok($2 eq $pitch, "[status.pitch:] returns $pitch");
			} elsif ($1 eq 'sleep') {
				ok($2 eq $sleep, "[status.sleep:] returns $sleep");
			} elsif ($1 eq 'playlist repeat') {
			} elsif ($1 eq 'playlist shuffle') {
			} elsif ($1 eq 'playlist_cur_index') {
			} elsif ($1 eq 'playlist_tracks') {
			} elsif ($1 eq 'time') {
			} elsif ($1 eq 'duration') {
			} elsif ($1 eq 'mode') {
			} elsif ($1 eq 'rescan') {  	#Returned with value 1 if the SlimServer is still scanning the database. The results may therefore be incomplete. Not returned if no scan is in progress.
			} else {
				ok(0, "[status] returns unknown tag: $1");
			}
		}
	}
	
	print("\n\nFinished testing random config, restoring players state...\n");
	for(my $i = 0; $i < $numPlayers; $i++)
	{
		cmd($players[$i], ['mixer', 'volume', $playersData{"mixer volume $i"}]);
		cmd($players[$i], ['mixer', 'bass', $playersData{"mixer bass $i"}]);
		cmd($players[$i], ['mixer', 'treble', $playersData{"mixer treble $i"}]);
		cmd($players[$i], ['mixer', 'pitch', $playersData{"mixer pitch $i"}]);
		cmd($players[$i], ['rate', $playersData{"rate $i"}]);
		cmd($players[$i], ['sleep', 0]);
	}


	print("\n\nAll players restored!\n");
	sleep 3 if $numPlayers;;

	# display n N n
	showTestTitle("Display test");
	for(my $i = 0; $i < $numPlayers; $i++)
	{
		cmd($players[$i], ['display', 'Testing:', "Player $i", 5]);
	}
	for(my $i = 0; $i < $numPlayers; $i++)
	{
		my @results = query_dual($players[$i], ['displaynow']);
		ok($results[0] eq "Testing:", "[displaynow ? ?] returns correct first line");
		ok($results[1] eq "Player $i", "[displaynow ? ?] returns correct second line");
	}
	sleep 4 if $numPlayers;
	
	#WARNING: display ? ? not tested
	
	
	# button
	# playerpref
	showTestTitle("Button/playerpref test");
	for(my $i = 0; $i < $numPlayers; $i++)
	{
		cmd($players[$i], ['playerpref', 'powerOnBrightness', 4]);
	}
	for(my $i = 0; $i < $numPlayers; $i++)
	{
		cmd($players[$i], ['button', 'brightness_down']);
		cmd($players[$i], ['button', 'brightness_down']);
	}
	for(my $i = 0; $i < $numPlayers; $i++)
	{
		ok(queryNum($players[$i], ['playerpref', 'powerOnBrightness']) eq "2", "2 button presses lower brightness by 2 units");
		cmd($players[$i], ['playerpref', 'powerOnBrightness', $playersData{"playerpref powerOnBrightness $i"}]);
	}
	
	
	# sync
	# mixer muting
	# ir
}

# ---------------------------------------------
sub databaseCommandsTests
{
	showTestTitle("Database tests");

	my $done;
	
#rescan
#wipecache

	if (!($sSkip =~ /r/)) {
		showTestTitle("Rescan");
		cmd(undef, ['rescan']);
		
		testDBrescan(undef, 'genres');
		testDBrescan(undef, 'artists');
		testDBrescan(undef, 'albums');
		testDBrescan(undef, 'songs');
		testDBrescan(undef, 'songinfo');
		testDBrescan(undef, 'playlists');
	
		SKIP:{
			skip('no players') if !scalar @players;
		
			testDBrescan($players[0], 'status');
		}
		
		#wait for rescan to be done...
		print("\n\nWaiting for rescan to finish...");
		$done = 0;
		while(!$done) {
			sleep 4;
			$done = !testDBrescan(undef, 'genres', 0);
		}
		
	
		showTestTitle("Wipecache");
		cmd(undef, ['wipecache']);
		
		testDBrescan(undef, 'genres');
		testDBrescan(undef, 'artists');
		testDBrescan(undef, 'albums');
		testDBrescan(undef, 'songs');
		testDBrescan(undef, 'songinfo');
		testDBrescan(undef,  'playlists');
	
		SKIP:{
			skip('no players') if !scalar @players;
		
			testDBrescan($players[0], 'status');
		}
			
		#wait for rescan to be done...
		print("\n\nWaiting for rescan (wipecache) to finish...\n");
		$done = 0;
		while(!$done) {
			sleep 4;
			$done = !testDBrescan(undef, 'genres', 0);
		}
	}
	
#info total genres ?
#info total artists ?
#info total albums ?
#info total songs ?
	print("\n\nRefreshing counts after rescan...\n");
	my $genreCount = queryNum(undef, ['info', 'total', 'genres']);
	my $artistsCount = queryNum(undef, ['info', 'total', 'artists']);
	my $albumsCount = queryNum(undef, ['info', 'total', 'albums']);
	my $songsCount = queryNum(undef, ['info', 'total', 'songs']);


	print("\n\nDumping database...\n");
	%database = dumpDB();
	
		
#genres <start> <itemsPerResponse> <taggedParameters>

#search 	Search substring. The search is case insensitive.

#rescan 	Returned with value 1 if the SlimServer is still scanning the database. The results may therefore be incomplete. Not returned if no scan is in progress.
#count 	Number of results returned by the query. If no search string is present, this is the same value as returned by "info total genres ?"
#  genre 	Genre name. Item delimiter.

	showTestTitle("Testing [genres] query");
		
	my %genres = testDBsearch('genre', $genreCount, 'ro');;
	my $test = 1;
	
	print("\n\nTesting genres vs DB...\n");
	
	foreach my $genre (keys %genres){
		$test = $test && defined($database{$genre});
		if(!$test){
			printf("'$genre' is not in DB!\n");
			last;
		}
	}
	ok($test, , "[genres] returned genres are all in DB");
	$test = 1;
	foreach my $genre (keys %database){
		$test = $test && defined($genres{$genre});
		if(!$test){
			printf("'$genre' is not in [genres]!\n");
			last;
		}
	}
	ok($test, , "[db] genres are all returned by [genres]");
	
#artists <start> <itemsPerResponse> <taggedParameters>

#search 	Search substring. The search is case insensitive.
#genre 	Genre name, to restrict the results to those artists with songs of that genre.
#album 	Album name, to restrict the results to those artists with songs of that album.

#rescan 	Returned with value 1 if the SlimServer is still scanning the database. The results may therefore be incomplete. Not returned if no scan is in progress.
#count 	Number of results returned by the query. If no search string is present, this is the same value as returned by "info total artists ?"
#  artist 	Artist name. Item delimiter.

	showTestTitle("Testing [artists] query");
		
	my %artists = testDBsearch('artist', $artistsCount, 'ba');

	$test = 1;
	
	print("\n\nTesting artists vs DB...\n");
	
	foreach my $artist (keys %artists){
		my $found = 0;
		foreach my $g(keys %database){
			foreach my $a (keys %{$database{$g}}){
				$found = defined $database{$g}{$artist};
				last if $found;
			}
			last if $found;
		}
		$test = $test && $found;
		if(!$test){
			print("'$artist' not found in DB...\n");
			last;
		}
	}
	ok($test, , "[artists] returned artists are all in DB");
	$test = 1;
	foreach my $g (keys %database){
		foreach my $a (keys %{$database{$g}}){
			$test = $test && defined($artists{$a});
			if(!$test){
				print("'$a' not found in [artists]...\n");
				last;
			}
		}
		last if !$test;
	}
	ok($test, , "[db] artists are all returned by [artists]");
		
#albums <start> <itemsPerResponse> <taggedParameters>

#search 	Search substring. The search is case insensitive.
#genre 	Genre name, to restrict the results to those albums with songs of that genre.
#artist 	Artist name, to restrict the results to those albums with songs of that artist.

#rescan 	Returned with value 1 if the SlimServer is still scanning the database. The results may therefore be incomplete. Not returned if no scan is in progress.
#count 	Number of results returned by the query. If no search string is present, this is the same value as returned by "info total albums ?"
#For each album: 	
#  album 	Album name. Item delimiter.

	showTestTitle("Testing [albums] query");
		
	my %albums = testDBsearch('album', $albumsCount, 'ba');

	$test = 1;
	
	print("\n\nTesting albums vs DB...\n");
	
	foreach my $album (keys %albums){
		my $found = 0;
		foreach my $g(keys %database){
			foreach my $a (keys %{$database{$g}}){
				foreach my $l (keys %{$database{$g}{$a}}){
					$found = defined $database{$g}{$a}{$album};
					last if $found;
				}
				last if $found;
			}
			last if $found;
		}
		$test = $test && $found;
		if(!$test){
			printf("'$album' is not in DB!\n");
			last;
		}
	}
	ok($test, , "[albums] returned albums are all in DB");
	$test = 1;
	foreach my $g (keys %database){
		foreach my $a (keys %{$database{$g}}){
			foreach my $l (keys %{$database{$g}{$a}}){
				$test = $test && defined($albums{$l});
				if(!$test){
					print("'$l' not found in [albums]...\n");
					last;
				}
			}
		}
	}
	ok($test, , "[db] albums are all returned by [albums]");

#titles|songs <start> <itemsPerResponse> <taggedParameters>

#genre 	Genre name, to restrict the results to the titles of that genre.
#artist 	Artist name, to restrict the results to the titles of that artist.
#album 	Album name, to restrict the results to the titles of that album.
#tags 	Determines which tags are returned. Each returned tag is identified by a letter (see command "songinfo" for a list of possible fields and their identifying letter). The default tags value for this command is "galdp".
#search 	Search substring. The search is case insensitive.
#sort 	Sorting, one of "titles" (the default) or "tracks". The track field ("t") is added automatically to the response. Sorting by tracks is possible only if tracks are defined and for a single album.

#rescan 	Returned with value 1 if the SlimServer is still scanning the database. The results may therefore be incomplete. Not returned if no scan is in progress.
#count 	Number of results returned by the query. If no search string is present, this is the same value as returned by "info total songs ?"
#  index 	Title index, zero-based. Item delimiter.
#  Tags 	Same tags as defined in command "songinfo".


	showTestTitle("Testing [titles] query");
		
	my %titles = testDBsearch('title', $songsCount, 'ba', 'tags:');

	$test = 1;
	
	print("\n\nTesting titles vs DB...\n");
	
	foreach my $title (keys %titles){
		my $found = 0;
		foreach my $g(keys %database){
			foreach my $a (keys %{$database{$g}}){
				foreach my $l (keys %{$database{$g}{$a}}){
					$found = defined $database{$g}{$a}{$l}{$title};
					last if $found;
				}
				last if $found;
			}
			last if $found;
		}
		$test = $test && $found;
		if(!$test){
			printf("'$title' is not in DB!\n");
			last;
		}
	}
	ok($test, , "[titles] returned titles are all in DB");
	$test = 1;
	foreach my $g (keys %database){
		foreach my $a (keys %{$database{$g}}){
			foreach my $l (keys %{$database{$g}{$a}}){
				foreach my $t (keys %{$database{$g}{$a}{$l}}){
					$test = $test && defined($titles{$t});
					if(!$test){
						print("'$t' not found in [titles]...\n");
						last;
					}
				}
			}
		}
	}
	ok($test, , "[db] titles are all returned by [titles]");

	sleep 3;



#playlists <start> <itemsPerResponse> <taggedParameters>

#dir 	Virtual playlist directory, as returned below (dig down).
#search 	Search substring. The search is case insensitive and performed on the item name (song title, directory name or playlist name).
#tags 	Determines which tags are returned. Each returned tag is identified by a letter (see below). The default value is "galdp".

#rescan 	Returned with value 1 if the SlimServer is still scanning the database. The results may therefore be incomplete. Not returned if no scan is in progress.
#count 	Number of results returned by the query.
#  index 	Item index, zero-based. Item delimiter.
#  If item is path: 	
#   item 	Name of the playlist or directory
#    dir 	Virtual playlist directory to dig down into playlist or directory
#  If item is song: 	
#    Tags 	Same tags as defined in command "songinfo".

	showTestTitle("Testing [playlists] query");

	testPlaylist();

	foreach my $item (keys %playlists){
		printf("Path: <$item> is $playlists{$item}\n");
	}

	#WARNING: search not tested for playlists
	
	
#songinfo <start> <itemsPerResponse> <taggedParameters>

#path 	Song path as returned by other CLI commands. This is a mandatory parameter.
#tags 	Determines which tags are returned. Each returned tag is identified by a letter (see below). The default value is all info except the path.

#	rescan 	Returned with value 1 if the SlimServer is still scanning the database. The results may therefore be incomplete. Not returned if no scan is in progress.
#	count 	Number of results returned by the query, that is, total number of elements to return for this song.
#	title 	Song title
#g 	genre 	Genre name. Only if known.
#a 	artist 	Artist name. Only if known.
#c 	composer 	Composer name. Only if known.
#b 	band 	Band name. Only if known.
#u 	conductor 	Conductor name. Only if known.
#l 	album 	Album name. Only if known.
#d 	duration 	Song duration in seconds.
#i 	disc 	Disc number. Only if known.
#q 	disccount 	Number of discs. Only if known.
#t 	track 	Track number. Only if known.
#y 	year 	Song year. Only if known.
#m 	bpm 	Beats per minute. Only if known.
#k 	comment 	Song comments, if any.
#o 	type 	Content type. Only if known.
#v 	tagversion 	Version of tag information in song file. Only if known.
#r 	bitrate 	Song bitrate. Only if known.
#f 	filelength 	Song file length in bytes. Only if known.
#z 	drm 	Digital rights information. Only if known.
#j 	coverart 	1 if coverart is available for this song. Not listed otherwise.
#h 	coverthumb 	1 if cover thumbnail is available for this song. Not listed otherwise.
#n 	modtime 	Date and time song file was last changed.
#p 	path 	Song file path. Used as <item> parameter for the "playlist add" command, for example.

	showTestTitle("Testing [songinfo] query");

# find a song in the db
	my $path = randomSong();
	
	$done = 0;
	my @results;
	my $once = 1;
	my $count = 0;

	while (($done < $count) || $once) {
		my $from = $done;
		my $items = ceil(rand ($count - $done));
		if($items < 1) {
			$items = 1;
		}
		$once = 0;
		my $test = 1;
	
		@results = eCLIquery(undef, ['songinfo', $from, $items, "url:$path"]);

		for(my $i = 4; $i < scalar(@results); $i++){	
			$results[$i] =~ /([^:]+):(.*)/;
			
			$done++;
			if($1 eq 'count') {
				if($from == 0) {
					$count = $2;
				}
				$done--;
			} elsif ($1 eq 'title') {
			} elsif ($1 eq 'genre') {
			} elsif ($1 eq 'artist') {
			} elsif ($1 eq 'composer') {
			} elsif ($1 eq 'conductor') {
			} elsif ($1 eq 'band') {
			} elsif ($1 eq 'album') {
			} elsif ($1 eq 'duration') {
			} elsif ($1 eq 'disc') {
			} elsif ($1 eq 'disccount') {
			} elsif ($1 eq 'tracknum') {
			} elsif ($1 eq 'year') {
			} elsif ($1 eq 'bpm') {
			} elsif ($1 eq 'comment') {
			} elsif ($1 eq 'type') {
			} elsif ($1 eq 'tagversion') {
			} elsif ($1 eq 'bitrate') {
			} elsif ($1 eq 'filesize') {
			} elsif ($1 eq 'drm') {
			} elsif ($1 eq 'coverart') {
			} elsif ($1 eq 'coverthumb') {
			} elsif ($1 eq 'modificationTime') {
			} elsif ($1 eq 'url') {
			} else {
				ok(0, "[songinfo] returns unknown tag: $1");
			}
		}
	}
}

# ---------------------------------------------
sub playlistCommandsTests()
{

	showTestTitle('playlistCommandsTests()');

	return if($songsCount < 10);
	

	
	#find three long enough songs...
	printf("Finding 5 long enough songs...\n");
	my @songs;
	push @songs, randomLongSong();
	while(scalar @songs < 5){
		printf("Looking for unique random song...\n");
		my $song = randomLongSong();
		my $found = 0;
		foreach my $p (@songs){
			if ($p eq $song){
				$found = 1;
				last;
			}
		}
		if(!$found){
			push @songs, $song;
		}
	}
	
	showTestTitle('playlist play/add/insert with song paths');
#<playerid> playlist play songpath
#<playerid> playlist add songpath
#<playerid> playlist insert songpath
	for (my $i=0; $i<scalar @players; $i++){
		#check config
#<playerid> playlist shuffle ?
		ok(queryFlag($players[$i], ['playlist', 'shuffle']) eq "0", "[playlist shuffle ?] returns no shuffle");
#<playerid> playlist repeat ?
		ok(queryFlag($players[$i], ['playlist', 'repeat']) eq "0", "[playlist repeat ?] returns no repeat");

		#add songs
		cmd($players[$i], ["playlist", "play", $songs[0]]);
		cmd($players[$i], ["playlist", "add", $songs[2]]);
		cmd($players[$i], ["playlist", "insert", $songs[1]]);
		cmd($players[$i], ["playlist", "add", $songs[4]]);
		cmd($players[$i], ["playlist", "add", $songs[3]]);
#<playerid> playlist move <fromindex> <toindex>

		cmd($players[$i], ["playlist", "move", 3, 4]);
		
		#now we should have a playlist in array order...
	}
	
	printf("Added 5 songs to players playlists\n");
	sleep 2 if scalar @players;
	
#<playerid> genre ?
#<playerid> artist ?
#<playerid> album ?
#<playerid> title ?
#<playerid> duration ?
#<playerid> path ?
#<playerid> playlist tracks ?
#<playerid> playlist index ?

	for (my $i=0; $i<scalar @players; $i++){
		ok(queryNum($players[$i], ['playlist', 'tracks']) eq "5", "[playlist tracks ?] returns correct number of tracks");
		ok(queryNum($players[$i], ['playlist', 'index']) eq "0", "[playlist index ?] returns correct index");

		ok(query($players[$i], ["genre"]) eq songInfo($songs[0], 'genre'), "[genre ?] returns played song");	
		ok(query($players[$i], ["artist"]) eq songInfo($songs[0], 'artist'), "[artist ?] returns played song");
		ok(query($players[$i], ["album"]) eq songInfo($songs[0], 'album'), "[album ?] returns played song");
		ok(query($players[$i], ["duration"]) eq songInfo($songs[0], 'duration'), "[duration ?] returns played song");
		ok(query($players[$i], ["path"]) eq $songs[0], "[path ?] returns played song");
		ok(query($players[$i], ["mode"]) eq "play", "[mode ?] returns play");
		
		my @results = eCLIquery($players[$i], ['status', '-', 1, 'tags:galu']);
		my $idxcnt = 0;
		for(my $j = 5; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			
			if ($1 eq 'player_name') {
			} elsif ($1 eq 'player_connected') {
			} elsif ($1 eq 'power') {
			} elsif ($1 eq 'signalstrength') {
			} elsif ($1 eq 'rate') { 	
			} elsif ($1 eq 'will_sleep_in') { 	#Minutes lefts until sleeping. Only if set to sleep.
			} elsif ($1 eq 'mixer volume') {
			} elsif ($1 eq 'mixer treble') { 
			} elsif ($1 eq 'mixer bass') { 	
			} elsif ($1 eq 'mixer pitch') {
			} elsif ($1 eq 'sleep') { 	#If set to sleep, the amount it was set to.
			} elsif ($1 eq 'playlist repeat') { 	#0 no repeat, 1 repeat song, 2 repeat playlist.
			} elsif ($1 eq 'playlist shuffle') { 	#0 no shuffle, 1 shuffle songs, 2 shuffle albums.
			} elsif ($1 eq 'playlist_cur_index') {
				ok($2 eq "0", "[status.playlist_cur_index] returns correct current index");
			} elsif ($1 eq 'playlist_tracks') {
				ok($2 eq "5", "[status.playlist_tracks] returns correct number of tracks");
			} elsif ($1 eq 'time') { 	#Elapsed time into the current song. Decimal seconds. Only if current song.
			} elsif ($1 eq 'duration') { 	#Duration of the current song. Decimal seconds. Only if current song.
				ok($2 eq songInfo($songs[0], 'duration'), "[status.duration] returns played song");
			} elsif ($1 eq 'mode') { 	#Player mode.
				ok($2 eq "play", "[status.mode] returns play");
			} elsif ($1 eq 'rescan') {  	#Returned with value 1 if the SlimServer is still scanning the database. The results may therefore be incomplete. Not returned if no scan is in progress.
			} elsif ($1 eq 'playlist index') {
				$idxcnt++;
			} elsif ($1 eq 'title') {
				ok($2 eq songInfo($songs[0], 'title'), "[status.title] returns played song");
			} elsif ($1 eq 'artist') {
				ok($2 eq songInfo($songs[0], 'artist'), "[status.artist] returns played song");
			} elsif ($1 eq 'album') {
				ok($2 eq songInfo($songs[0], 'album'), "[status.album] returns played song");
			} elsif ($1 eq 'url') {
				ok($2 eq $songs[0], "[status.url] returns played song");
			} elsif ($1 eq 'genre') {
				ok($2 eq songInfo($songs[0], 'genre'), "[status.genre] returns played song");
			} else {
				ok(0, "[status] returns unknown tag: $1");
			}			
		}
#<playerid> pause <0|1|> ()		
		cmd($players[$i], ["pause"]);
	}
	
	printf("\nPaused players\n");
	sleep 2 if scalar @players;
	
	for (my $i=0; $i<scalar @players; $i++){
		ok(query($players[$i], ["mode"]) eq "pause", "[mode ?] returns pause");
		
		my @results = eCLIquery($players[$i], ['status', 0, 0]);
		for(my $j = 4; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			if ($1 eq 'mode') { 	#Player mode.
				ok($2 eq "pause", "[status.mode] returns pause");
			}			
		}
#<playerid> pause <0|1|> (0)
		cmd($players[$i], ["pause", 0]);
	}
	
	printf("\nRestarted players\n");
	sleep 2 if scalar @players;
	
	for (my $i=0; $i<scalar @players; $i++){
#<playerid> mode <play|pause|stop|?> (?)
		ok(query($players[$i], ["mode"]) eq "play", "[mode ?] returns play");
		
		my @results = eCLIquery($players[$i], ['status', 0, 0]);
		for(my $j = 4; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			if ($1 eq 'mode') { 	#Player mode.
				ok($2 eq "play", "[status.mode] returns play");
			}			
		}
#<playerid> mode <play|pause|stop|?> (mode stop)
		cmd($players[$i], ["mode", "stop"]);
	}

	printf("\nStopped players\n");
	sleep 2 if scalar @players;
	
	for (my $i=0; $i<scalar @players; $i++){
#<playerid> mode <play|pause|stop|?> (?)
		ok(query($players[$i], ["mode"]) eq "stop", "[mode ?] returns stop");
		
		my @results = eCLIquery($players[$i], ['status', 0, 0]);
		for(my $j = 4; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			if ($1 eq 'mode') { 	#Player mode.
				ok($2 eq "stop", "[status.mode] returns stop");
			}			
		}
#<playerid> play
		cmd($players[$i], ["play"]);
	}

	printf("\nRestarted players\n");
	sleep 2 if scalar @players;
	
	for (my $i=0; $i<scalar @players; $i++){
#<playerid> mode ?
		ok(query($players[$i], ["mode"]) eq "play", "[mode ?] returns play");
		
		my @results = eCLIquery($players[$i], ['status', 0, 0]);
		for(my $j = 4; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			if ($1 eq 'mode') { 	#Player mode.
				ok($2 eq "play", "[status.mode] returns play");
			}			
		}
#<playerid> stop
		cmd($players[$i], ["stop"]);
	}
		
	printf("\nStopped players\n");
	sleep 2 if scalar @players;
	
	for (my $i=0; $i<scalar @players; $i++){
#<playerid> mode <play|pause|stop|?> (?)
		ok(query($players[$i], ["mode"]) eq "stop", "[mode ?] returns stop");
		
		my @results = eCLIquery($players[$i], ['status', 0, 0]);
		for(my $j = 4; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			if ($1 eq 'mode') { 	#Player mode.
				ok($2 eq "stop", "[status.mode] returns stop");
			}			
		}
#<playerid> mode play
		cmd($players[$i], ["mode", "play"]);
	}

	printf("\nRestarted players\n");
	sleep 2 if scalar @players;
	
	for (my $i=0; $i<scalar @players; $i++){
#<playerid> mode <play|pause|stop|?> (?)
		ok(query($players[$i], ["mode"]) eq "play", "[mode ?] returns play");
		
		my @results = eCLIquery($players[$i], ['status', 0, 0]);
		for(my $j = 4; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			if ($1 eq 'mode') { 	#Player mode.
				ok($2 eq "play", "[status.mode] returns play");
			}			
		}
#<playerid> mode pause
		cmd($players[$i], ["mode", "pause"]);
	}

	printf("\nPaused players\n");
	sleep 2 if scalar @players;
	
	for (my $i=0; $i<scalar @players; $i++){
		ok(query($players[$i], ["mode"]) eq "pause", "[mode ?] returns pause");
		
		my @results = eCLIquery($players[$i], ['status', 0, 0]);
		for(my $j = 4; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			if ($1 eq 'mode') { 	#Player mode.
				ok($2 eq "pause", "[status.mode] returns pause");
			}			
		}
#<playerid> pause 0
		cmd($players[$i], ["pause", 0]);
	}

	printf("\nRestarted players\n");
	sleep 2 if scalar @players;
	
	for (my $i=0; $i<scalar @players; $i++){
#<playerid> mode <play|pause|stop|?> (?)
		ok(query($players[$i], ["mode"]) eq "play", "[mode ?] returns play");
		
		my @results = eCLIquery($players[$i], ['status', 0, 0]);
		for(my $j = 4; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			if ($1 eq 'mode') { 	#Player mode.
				ok($2 eq "play", "[status.mode] returns play");
			}			
		}
#<playerid> pause 1
		cmd($players[$i], ["pause", 1]);
	}

	printf("\nPaused players\n");
	sleep 2 if scalar @players;
	
	for (my $i=0; $i<scalar @players; $i++){
		ok(query($players[$i], ["mode"]) eq "pause", "[mode ?] returns pause");
		
		my @results = eCLIquery($players[$i], ['status', 0, 0]);
		for(my $j = 4; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			if ($1 eq 'mode') { 	#Player mode.
				ok($2 eq "pause", "[status.mode] returns pause");
			}			
		}
#<playerid> pause 0
		cmd($players[$i], ["pause", 0]);
	}

	printf("\nRestarted players\n");
	sleep 2 if scalar @players;

	showTestTitle("Checking playlist order");


#<playerid> playlist genre <index> ?
#<playerid> playlist artist <index> ?
#<playerid> playlist album <index> ?
#<playerid> playlist title <index> ?
#<playerid> playlist duration <index> ?
#<playerid> playlist path <index> ?

	for (my $i=0; $i<scalar @players; $i++){
		for (my $k=0; $k<5; $k++){
			ok(query($players[$i], ["playlist", "genre", $k]) eq songInfo($songs[$k], 'genre'), "[playlist genre $k ?] matches playlist");	
			ok(query($players[$i], ["playlist", "artist", $k]) eq songInfo($songs[$k], 'artist'), "[playlist artist $k ?] matches playlist");
			ok(query($players[$i], ["playlist", "album", $k]) eq songInfo($songs[$k], 'album'), "[playlist album $k ?] matches playlist");
			ok(query($players[$i], ["playlist", "duration", $k]) eq songInfo($songs[$k], 'duration'), "[playlist duration $k ?] matches playlist");
			ok(query($players[$i], ["playlist", "path", $k]) eq $songs[$k], "[playlist path $k ?] matches playlist");
		}
		my @results = eCLIquery($players[$i], ['status', '-', 5, 'tags:galud']);
		my $idxcnt = 0;
		for(my $j = 5; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			
			if ($1 eq 'player_name') {
			} elsif ($1 eq 'player_connected') {
			} elsif ($1 eq 'power') {
			} elsif ($1 eq 'signalstrength') {
			} elsif ($1 eq 'rate') { 	
			} elsif ($1 eq 'will_sleep_in') { 	#Minutes lefts until sleeping. Only if set to sleep.
			} elsif ($1 eq 'mixer volume') {
			} elsif ($1 eq 'mixer treble') { 
			} elsif ($1 eq 'mixer bass') { 	
			} elsif ($1 eq 'mixer pitch') {
			} elsif ($1 eq 'sleep') { 	#If set to sleep, the amount it was set to.
			} elsif ($1 eq 'playlist repeat') { 	#0 no repeat, 1 repeat song, 2 repeat playlist.
			} elsif ($1 eq 'playlist shuffle') { 	#0 no shuffle, 1 shuffle songs, 2 shuffle albums.
			} elsif ($1 eq 'playlist_cur_index') {
			} elsif ($1 eq 'playlist_tracks') {
			} elsif ($1 eq 'time') { 	#Elapsed time into the current song. Decimal seconds. Only if current song.
			} elsif ($1 eq 'duration') { 	#Duration of the current song. Decimal seconds. Only if current song.
				ok($2 eq songInfo($songs[$idxcnt], 'duration'), "[status.$idxcnt.duration] matches playlist");
			} elsif ($1 eq 'mode') { 	#Player mode.
			} elsif ($1 eq 'rescan') {  	#Returned with value 1 if the SlimServer is still scanning the database. The results may therefore be incomplete. Not returned if no scan is in progress.
			} elsif ($1 eq 'playlist index') {
				$idxcnt=$2;
			} elsif ($1 eq 'title') {
				ok($2 eq songInfo($songs[$idxcnt], 'title'), "[status.$idxcnt.title] returns played song");
			} elsif ($1 eq 'artist') {
				ok($2 eq songInfo($songs[$idxcnt], 'artist'), "[status.$idxcnt.artist] returns played song");
			} elsif ($1 eq 'album') {
				ok($2 eq songInfo($songs[$idxcnt], 'album'), "[status.$idxcnt.album] returns played song");
			} elsif ($1 eq 'url') {
				ok($2 eq $songs[$idxcnt], "[status.$idxcnt.url] returns played song");
			} elsif ($1 eq 'genre') {
				ok($2 eq songInfo($songs[$idxcnt], 'genre'), "[status.$idxcnt.genre] returns played song");
			} else {
				ok(0, "[status] returns unknown tag: $1");
			}			
		}
	}

	showTestTitle("Skip testing");

#<playerid> playlist index +index
	for (my $i=0; $i<scalar @players; $i++){
		cmd($players[$i], ["playlist", "index", "+1"]);
	}

	for (my $i=0; $i<scalar @players; $i++){
		ok(queryNum($players[$i], ['playlist', 'index']) eq "1", "[playlist index ?] returns correct index after skip +1");

		my @results = eCLIquery($players[$i], ['status', '-', 1, 'tags:alug']);
		for(my $j = 5; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			
			if ($1 eq 'playlist_cur_index') {
				ok($2 eq "1", "[status.playlist_cur_index] returns correct index after skip +1");
			} elsif ($1 eq 'title') {
				ok($2 eq songInfo($songs[1], 'title'), "[status.-.title] returns correct song");
			} elsif ($1 eq 'artist') {
				ok($2 eq songInfo($songs[1], 'artist'), "[status.-.artist] returns correct song");
			} elsif ($1 eq 'album') {
				ok($2 eq songInfo($songs[1], 'album'), "[status.-.album] returns correct song");
			} elsif ($1 eq 'url') {
				ok($2 eq $songs[1], "[status.-.url] returns correct song");
			} elsif ($1 eq 'genre') {
				ok($2 eq songInfo($songs[1], 'genre'), "[status.-.genre] returns correct song");
			}
		}
	}

#<playerid> playlist index -index
	for (my $i=0; $i<scalar @players; $i++){
		cmd($players[$i], ["playlist", "index", "-1"]);
	}

	for (my $i=0; $i<scalar @players; $i++){
		ok(queryNum($players[$i], ['playlist', 'index']) eq "0", "[playlist index ?] returns correct index after skip -1");

		my @results = eCLIquery($players[$i], ['status', '-', 1, 'tags:alug']);
		for(my $j = 5; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			
			if ($1 eq 'playlist_cur_index') {
				ok($2 eq "0", "[status.playlist_cur_index] returns correct index after skip +1");
			} elsif ($1 eq 'title') {
				ok($2 eq songInfo($songs[0], 'title'), "[status.-.title] returns correct song");
			} elsif ($1 eq 'artist') {
				ok($2 eq songInfo($songs[0], 'artist'), "[status.-.artist] returns correct song");
			} elsif ($1 eq 'album') {
				ok($2 eq songInfo($songs[0], 'album'), "[status.-.album] returns correct song");
			} elsif ($1 eq 'url') {
				ok($2 eq $songs[0], "[status.-.url] returns correct song");
			} elsif ($1 eq 'genre') {
				ok($2 eq songInfo($songs[0], 'genre'), "[status.-.genre] returns correct song");
			}
		}
	}
	
#<playerid> playlist index index
	for (my $i=0; $i<scalar @players; $i++){
		cmd($players[$i], ["playlist", "index", 2]);
	}

	for (my $i=0; $i<scalar @players; $i++){
		ok(queryNum($players[$i], ['playlist', 'index']) eq "2", "[playlist index ?] returns correct index after index 2");

		my @results = eCLIquery($players[$i], ['status', '-', 1, 'tags:alug']);
		for(my $j = 5; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			
			if ($1 eq 'playlist_cur_index') {
				ok($2 eq "2", "[status.playlist_cur_index] returns correct index after skip +1");
			} elsif ($1 eq 'title') {
				ok($2 eq songInfo($songs[2], 'title'), "[status.-.title] returns correct song");
			} elsif ($1 eq 'artist') {
				ok($2 eq songInfo($songs[2], 'artist'), "[status.-.artist] returns correct song");
			} elsif ($1 eq 'album') {
				ok($2 eq songInfo($songs[2], 'album'), "[status.-.album] returns correct song");
			} elsif ($1 eq 'url') {
				ok($2 eq $songs[2], "[status.-.url] returns correct song");
			} elsif ($1 eq 'genre') {
				ok($2 eq songInfo($songs[2], 'genre'), "[status.-.genre] returns correct song");
			}
		}
	}
	
	showTestTitle("Moving time test");


#<playerid> time number
	for (my $i=0; $i<scalar @players; $i++){
		cmd($players[$i], ["time", 100]);
	}
	
#<playerid> time ?
	for (my $i=0; $i<scalar @players; $i++){	
		ok(queryNum($players[$i], ['time']) >= 100, "[time 100] moves [time ?] at or after 100");

		my @results = eCLIquery($players[$i], ['status', '-', 1, 'tags:']);
		for(my $j = 5; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			
			if ($1 eq 'time') { 	#Elapsed time into the current song. Decimal seconds. Only if current song.
				ok($2 >= 100, "[time 100] moves [status.-.time] at or after 100");
			}
		}
	}

#<playerid> time +number
	for (my $i=0; $i<scalar @players; $i++){
		cmd($players[$i], ["time", "+100"]);
	}
	
#<playerid> time ?
	for (my $i=0; $i<scalar @players; $i++){	
		ok(queryNum($players[$i], ['time']) >= 200, "[time +100] moves [time ?] at or after 200");

		my @results = eCLIquery($players[$i], ['status', '-', 1, 'tags:']);
		for(my $j = 5; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			
			if ($1 eq 'time') { 	#Elapsed time into the current song. Decimal seconds. Only if current song.
				ok($2 >= 100, "[time +100] moves [status.-.time] at or after 200");
			}
		}
	}

#<playerid> time -number
	for (my $i=0; $i<scalar @players; $i++){
		cmd($players[$i], ["time", "-100"]);
	}
	
#<playerid> time ?
	for (my $i=0; $i<scalar @players; $i++){
		my $time = queryNum($players[$i], ['time']);
		ok($time >= 100, "[time -100] moves [time ?] after 100");
		ok($time < 200, "[time -100] moves [time ?] below 200");

		my @results = eCLIquery($players[$i], ['status', '-', 1, 'tags:']);
		for(my $j = 5; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			
			if ($1 eq 'time') { 	#Elapsed time into the current song. Decimal seconds. Only if current song.
				ok($2 >= 100, "[time -100] moves [time ?] after 100");
				ok($2 < 200, "[time -100] moves [time ?] below 200");
			}
		}
	}

	showTestTitle("Shuffle & delete songs");


#<playerid> playlist shuffle 1
	for (my $i=0; $i<scalar @players; $i++){	
		cmd($players[$i], ["playlist", "index", 0]);
		cmd($players[$i], ["playlist", "shuffle", 1]);
		ok(queryFlag($players[$i], ['playlist', 'shuffle']) == 1, "[playlist shuffle ?] is 1");
	}
	
	sleep 2 if scalar @players;

	#check playlist order...
	
	for (my $i=0; $i<scalar @players; $i++){
		my @paths;
		
		for (my $k=0; $k<5; $k++){
			push @paths, query($players[$i], ["playlist", "path", $k]);
		}
		
		my @results = eCLIquery($players[$i], ['status', '-', 5, 'tags:u']);
		my $idx = 0;
		for(my $j = 5; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			
			if ($1 eq 'playlist index') {
				$idx = $2;
			}
			elsif ($1 eq 'url') {
				ok($2 eq $paths[$idx], "[status.$idx.url] same as [playlist path $idx]");
			}
		}
		
		#now check @paths has a different order than @songs...
		#ignore currently playing song
		my $areEqual = 1;
		for(my $j = 1; $j < scalar(@songs); $j++){
			for(my $k = 1; $k < scalar(@paths); $k++){
				if ($songs[$j] eq $paths[$k]){
					$areEqual = $areEqual && ($j == $k);
					printf("Song $j moved to $k\n");
				}
			}
		}
		ok(!$areEqual, "Playlist shuffled, order not conserved");

		sleep 1;

#<playerid> playlist deleteitem <item>
#<playerid> playlist delete <songindex>
		cmd($players[$i], ["playlist", "deleteitem", $paths[1]]);
		cmd($players[$i], ["playlist", "delete", 3]);
		
		my @path2;
		ok(queryNum($players[$i], ['playlist', 'tracks']) eq "3", "[playlist tracks ?] returns correct number of tracks");
		for (my $k=0; $k<3; $k++){
			push @path2, query($players[$i], ["playlist", "path", $k]);
		}
		
		@results = eCLIquery($players[$i], ['status', '-', 3, 'tags:u']);
		$idx = 0;
		for(my $j = 5; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			
			if ($1 eq 'playlist index') {
				$idx = $2;
			} elsif ($1 eq 'playlist_tracks') {
				ok($2 eq "3", "[status.playlist_tracks] returns correct number of tracks");
			}
			elsif ($1 eq 'url') {
				ok($2 eq $path2[$idx], "[status.$idx.url] same as [playlist path $idx]");
			}
		}
		
		#now check @path2 has all songs in paths except #2 and #4...
# 0 1 2 3 4
# delete 1
# 0   1 2 3
# delete 3
# 0   1 2
		for(my $j = 0; $j < scalar(@paths); $j++){
			for(my $k = 0; $k < scalar(@path2); $k++){
				if ($paths[$j] eq $path2[$k]){
					ok(($j == 0 && $k == 0) || ($j == 2 && $k == 1) || ($j == 3 && $k == 2), "Deleted songs match! ($j, $k)");
				}
			}
		}

	}	

	showTestTitle("Repeat tests");

	for (my $i=0; $i<scalar @players; $i++){	
		cmd($players[$i], ["stop"]);
#<playerid> playlist clear
		cmd($players[$i], ["playlist", "clear"]);
		cmd($players[$i], ["playlist", "shuffle", 0]);
#<playerid> playlist repeat 1
		cmd($players[$i], ["playlist", "repeat", 1]);
		ok(queryNum($players[$i], ['playlist', 'repeat']) == 1, "[playlist repeat ?] is 1 after [playlist repeat 1]");
		ok(queryNum($players[$i], ['playlist', 'tracks']) == 0, "[playlist tracks ?] is 0 after [playlist clear]");
		my @results = eCLIquery($players[$i], ['status', "-", 1]);
		for(my $j = 4; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			if ($1 eq "playlist repeat"){
				ok($2 eq "1", "[status.playlist repeat] is 1 after [playlist repeat 1]");
			} elsif ($1 eq "playlist_tracks"){
				ok($2 eq "0", "[status.playlist_tracks] is 0 after [playlist clear]");
			}
		}


		
		for(my $j = 0; $j < scalar(@songs); $j++){
			cmd($players[$i], ["playlist", "add", $songs[$j]]);
		}
		
		cmd($players[$i], ["play"]);
		cmd($players[$i], ["playlist", "index", 4]);
		cmd($players[$i], ["time", songInfo($songs[4], 'duration') - 3]);
		
		printf("\nWaiting for playlist to loop to test repeat 1\n");
		sleep 5;
		
		ok(queryNum($players[$i], ["playlist", "index"]) == 4, "Looped to last song with repeat 1...");
		ok(query($players[$i], ["mode"]) eq "play", "... and still playing!");
		@results = eCLIquery($players[$i], ['status', "-", 1]);
		for(my $j = 4; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			if ($1 eq 'mode') { 	#Player mode.
				ok($2 eq "play", "[status.mode] still playing as well");
			} elsif ($1 eq 'playlist_cur_index'){
				ok($2 eq "4", "[status.playlist_cur_index] is 4...");
			}
		}
		
#<playerid> playlist repeat 2
		cmd($players[$i], ["playlist", "repeat", 2]);
		cmd($players[$i], ["playlist", "index", 4]);
		cmd($players[$i], ["time", songInfo($songs[4], 'duration') - 3]);
		ok(queryNum($players[$i], ['playlist', 'repeat']) == 2, "[playlist repeat ?] is 2");
		
		printf("\nWaiting for playlist to loop to test repeat 2\n");
		sleep 5;
		
		ok(queryNum($players[$i], ["playlist", "index"]) == 0, "Looped to first song with repeat 2...");
		ok(query($players[$i], ["mode"]) eq "play", "... and still playing!");
		@results = eCLIquery($players[$i], ['status', "-", 1]);
		for(my $j = 4; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			if ($1 eq 'mode') { 	#Player mode.
				ok($2 eq "play", "[status.mode] still playing as well");
			} elsif ($1 eq 'playlist_cur_index'){
				ok($2 eq "0", "[status.playlist_cur_index] is 0...");
			} elsif ($1 eq "playlist repeat"){
				ok($2 eq "2", "[status.playlist repeat] is 2...");
			}
		}

#<playerid> playlist repeat 
		cmd($players[$i], ["playlist", "repeat"]);
		cmd($players[$i], ["playlist", "index", 4]);
		cmd($players[$i], ["time", songInfo($songs[4], 'duration') - 15]);
		ok(queryNum($players[$i], ['playlist', 'repeat']) == 0, "[playlist repeat ?] after repeat toggle is 0");
		
		ok(query($players[$i], ["mode"]) eq "play", "Still playing!");
		printf("\nWaiting to check mode again...\n");
		sleep 6;

		ok(query($players[$i], ["mode"]) eq "play", "Still playing!");
		
		printf("\nWaiting for playlist to stop to test repeat 0\n");
		sleep 10;
		ok(query($players[$i], ["mode"]) eq "stop", "Stopped");


		@results = eCLIquery($players[$i], ['status', "-", 1]);
		for(my $j = 4; $j < scalar(@results); $j++){	
			$results[$j] =~ /([^:]+):(.*)/;
			if ($1 eq 'mode') { 	#Player mode.
				ok($2 eq "stop", "[status.mode] stopped as well");
			} elsif ($1 eq "playlist repeat"){
				ok($2 eq "0", "[status.playlist repeat] is 0...");
			}
		}
		

	}


}

#<playerid> playlist play <item> [<title>]
#<playerid> playlist add <item>
#<playerid> playlist insert <item>



#<playerid> playlist shuffle <2|>

#<playerid> playlist loadalbum <genre> <artist> <album>
#<playerid> playlist addalbum <genre> <artist> <album>
#<playerid> playlist insertalbum <genre> <artist> <album>
#<playerid> playlist deletealbum <genre> <artist> <album>



#<playerid> playlist name ?
#<playerid> playlist url ?
#<playerid> playlist modified ?
#<playerid> playlist resume <playlist>
#<playerid> playlist save <playlist>

#shuffle off
#create a playlist
#save it
#clear
#resume playlist
#check playlist name, modified, url
#modify playlist
#check modified
#clear
#play playlist


#<playerid> playlist zap <songindex>
#playlist search

#zap a song
#look for Zapped playlist
#check song is last

sub randomAlbum{
	my @genreArray = keys %database;
	my $randGenre = $genreArray[int(rand(scalar @genreArray))];
	my @artistArray = keys %{$database{$randGenre}};
	my $randArtist = $artistArray[int(rand(scalar @artistArray))];
	my @albumArray = keys %{$database{$randGenre}{$randArtist}};
	my $randAlbum = $albumArray[int(rand(scalar @albumArray))];
	return ($randGenre, $randArtist, $randAlbum);
}

# ---------------------------------------------
sub randomSong{
	my ($randGenre, $randArtist, $randAlbum) = randomAlbum();
	my @titleArray = keys %{$database{$randGenre}{$randArtist}{$randAlbum}};
	my $randTitle = $titleArray[int(rand(scalar @titleArray))];
	return $database{$randGenre}{$randArtist}{$randAlbum}{$randTitle};
}

# ---------------------------------------------
sub randomLongSong{
	my $song;
	
	while(1){
		$song = randomSong();
		my @results = eCLIquery(undef, ['songinfo', 0, 2, "url:$song", "tags:d"]);
		for(my $i = 5; $i < scalar(@results); $i++){	
			$results[$i] =~ /([^:]+):(.*)/;
			if($1 eq 'count') {
			} elsif ($1 eq 'title') {
			} elsif ($1 eq 'duration') {
				if($2 > 60){
					return $song;
				}
			} else {
				ok(0, "[songinfo tags:d] returns unknown tag: $1");
			}
		}
	}
}

# ---------------------------------------------
sub songInfo{
	my $path = shift;
	my $field = shift;
	my $tags = field2tag($field);

	
#	rescan 	Returned with value 1 if the SlimServer is still scanning the database. The results may therefore be incomplete. Not returned if no scan is in progress.
#	count 	Number of results returned by the query, that is, total number of elements to return for this song.
#	title 	Song title
#g 	genre 	Genre name. Only if known.
#a 	artist 	Artist name. Only if known.
#c 	composer 	Composer name. Only if known.
#b 	band 	Band name. Only if known.
#u 	conductor 	Conductor name. Only if known.
#l 	album 	Album name. Only if known.
#d 	duration 	Song duration in seconds.
#i 	disc 	Disc number. Only if known.
#q 	disccount 	Number of discs. Only if known.
#t 	track 	Track number. Only if known.
#y 	year 	Song year. Only if known.
#m 	bpm 	Beats per minute. Only if known.
#k 	comment 	Song comments, if any.
#o 	type 	Content type. Only if known.
#v 	tagversion 	Version of tag information in song file. Only if known.
#r 	bitrate 	Song bitrate. Only if known.
#f 	filelength 	Song file length in bytes. Only if known.
#z 	drm 	Digital rights information. Only if known.
#j 	coverart 	1 if coverart is available for this song. Not listed otherwise.
#h 	coverthumb 	1 if cover thumbnail is available for this song. Not listed otherwise.
#n 	modtime 	Date and time song file was last changed.
#p 	path 	Song file path. Used as <item> parameter for the "playlist add" command, for example.
	
	

	my @results = eCLIquery(undef, ['songinfo', 0, 2, "url:$path", "tags:$tags"]);
	for(my $i = 5; $i < scalar(@results); $i++){	
		$results[$i] =~ /([^:]+):(.*)/;
		if($1 eq 'count') {
		} elsif ($field ne 'title' && $1 eq 'title') {
		} elsif ($1 eq $field) {
			return $2;
		} else {
			ok(0, "[songinfo tags:$tags] returns unknown tag: $1");
		}
	}
	return undef;
}

# ---------------------------------------------
sub field2tag{
	my $field = shift;
	
	return "" if !defined $field;
	
	if($field eq "genre"){
		return 'g';
	} elsif ($field eq "artist"){
		return 'a';
	} elsif ($field eq "composer"){
		return 'c';
	} elsif ($field eq "band"){
		return 'b';
	} elsif ($field eq "conductor"){
		return 'h';
	} elsif ($field eq "album"){
		return 'l';
	} elsif ($field eq "duration"){
		return 'd';
	} elsif ($field eq "disc"){
		return 'i';
	} elsif ($field eq "disccount"){
		return 'q';
	} elsif ($field eq "tracknum"){
		return 't';
	} elsif ($field eq "year"){
		return 'y';
	} elsif ($field eq "bpm"){
		return 'm';
	} elsif ($field eq "comment"){
		return 'k';
	} elsif ($field eq "type"){
		return 'o';
	} elsif ($field eq "tagversion"){
		return 'v';
	} elsif ($field eq "bitrate"){
		return 'r';
	} elsif ($field eq "filesize"){
		return 'f';
	} elsif ($field eq "drm"){
		return 'z';
	} elsif ($field eq "coverart"){
		return 'j';
	} elsif ($field eq "coverthumb"){
		return 'h';
	} elsif ($field eq "modificationTime"){
		return 'n';
	} elsif ($field eq "url"){
		return 'u';
	} elsif ($field eq "title"){
		return '';
	}
	printf("field2tag, unknown field $field\n");
	return "";
}

# ---------------------------------------------
sub dumpDB{

	my $done = 0;
	my %db;
	my @results;
	my $once = 1;
	my $artist = undef;
	my $album = undef;
	my $genre = undef;
	my $title = undef;
	my $path = undef;
	my $count = 0;

	while (($done < $count) || $once) {
		my $from = $done;
		my $items = ceil(rand ($count - $done));
		if($items < 1) {
			$items = 1;
		}
		$once = 0;
		my $test = 1;
	
		@results = eCLIquery(undef, ['titles', $from, $items, 'tags:algu']);

		for(my $i = 3; $i < scalar(@results); $i++){	
			$results[$i] =~ /([^:]+):(.*)/;
			
			if($1 eq 'count') {
				if($from == 0) {
					$count = $2;
				}
			} elsif ($1 eq 'album') {
				$album = $2;
			} elsif ($1 eq 'artist') {
				$artist = $2;
			} elsif ($1 eq 'genre') {
				$genre = $2;
			} elsif ($1 eq 'title') {
				$title = $2;
			} elsif ($1 eq 'url') {
				$path = $2;
			} elsif ($1 eq 'index') {
				if (defined($title)){
					$test = $test && defined $title && defined $genre && defined $artist && defined $album && defined $path;
					if (!$test) {
						printf("UNDEFINED: $title, $genre, $artist, $album, $path");
					}
					$db{ignoreCaseArticles($genre)}{ignoreCaseArticles($artist)}{ignoreCaseArticles($album)}{ignoreCaseArticles($title)} = $path;
					$genre = undef;
					$title = undef;
					$artist = undef;
					$album = undef;
					$path = undef;
				}
				$done++;
			}
		}
		if (defined($title)){
			$db{ignoreCaseArticles($genre)}{ignoreCaseArticles($artist)}{ignoreCaseArticles($album)}{ignoreCaseArticles($title)} = $title;
		}
		ok($test, "[titles.tag:algu] returns correct tags");
	}
		
	return %db;

}
# ---------------------------------------------
sub testDBrescan{
	my $client = shift;
	my $query = shift;
	my $test = shift;
	
	if(!defined $test){
		$test = 1;
	}
	my $first = 3;
	if(defined $client) {
		$first = 4;
	}

	my @results = eCLIquery($client, [$query, 0, 0]);
	my $foundRescan = 0;
	for(my $i = $first; $i < scalar(@results); $i++){	
		$results[$i] =~ /([^:]+):(.*)/;
		
		if ($1 eq 'rescan') {
			$foundRescan = 1;
		}
	}
	if($test == 1){
		ok($foundRescan, "[$query] signals rescan");
	}
	return $foundRescan;
}

# ---------------------------------------------
sub testDBsearch{
	my $query = shift;
	my $count = shift;
	my $pattern = shift;
	my $param = shift;

	my $done = 0;
	my %elements;
	my @results;
	
	while (($done < $count)) {
		my $from = $done;
		my $items = ceil(rand ($count - $done));
		if($items < 1) {
			$items = 1;
		}
	
		if(defined $param){
			@results = eCLIquery(undef, [$query . 's', $from, $items, $param]);
		} else {
			@results = eCLIquery(undef, [$query . 's', $from, $items]);
		}
		for(my $i = 3; $i < scalar(@results); $i++){	
			$results[$i] =~ /([^:]+):(.*)/;
			
			if($1 eq 'count') {
				if($from == 0) {
					ok($2 == $count, "[$query" . "s.count:]($2) is the same as [info total $query" ."s ?]($count)");
					$count = $2;
				}
			} elsif ($1 eq $query) {
				$done++;
				$elements{ignoreCaseArticles($2)} = $2;
			} elsif ($1 eq 'rescan') {
			} elsif ($1 eq 'index') {
			} elsif (defined($param) && "$1:$2" eq $param) {
			} else {
				ok(0, "[$query" ."s] returns unknown tag: $1");
			}
		}
	}
	
#	my $genre_pats = filterPats($genre);
#	my @genres     = filter($genre_pats, "", keys %genreCache);



	
	#search pattern
	my %elementsfnd = %elements;
	if(defined $param){
		@results = eCLIquery(undef, [$query . 's', 0, scalar(keys %elements), "search:$pattern", $param]);
	} else {
		@results = eCLIquery(undef, [$query . 's', 0, scalar(keys %elements), "search:$pattern"]);
	}
	my $test = 1;
	my $pattern_pats = filterPrep(ignoreCaseArticles("*" . $pattern . "*"));
#	printf("pattern_pats: $pattern_pats\n");
	for(my $i = 3; $i < scalar(@results); $i++){	
		$results[$i] =~ /([^:]+):(.*)/;
		
		if ($1 eq $query) {
			my $value = ignoreCaseArticles($2);
			$elementsfnd{$value} = " ";
			$test = $test && ignoreCaseArticles($elements{$value}) =~ $pattern_pats;
			if(!$test){
				printf("'$elements{$value}' does not contain search pattern!\n");
				last;
			}
		}
	}
	ok($test, "[$query" . "s] with search return elements containing search pattern");
	$test = 1;
	foreach my $elem (keys %elements){
		if($elementsfnd{$elem} ne " "){
			$test = $test && !(ignoreCaseArticles($elements{$elem}) =~ $pattern_pats);
			if(!$test){
				printf("'$elements{$elem}' contains search pattern!\n");
				last;
			}
		}
	}
	ok($test, "[$query" . "s] with search unreturned elements do not contain search pattern");
	
	return %elements;

}

# ---------------------------------------------
sub testPlaylist{
	my $item = shift;
	my $dir = shift;

	my $done = 0;
	my @results;
	my $once = 1;
#	my $artist;
	my $newItem;
#	my $genre;
	my $title;
	my $newDir;
	my $count = 0;

	while (($done < $count) || $once) {
		my $from = $done;
		my $items = ceil(rand ($count - $done));
		if($items < 1) {
			$items = 1;
		}
		$once = 0;
		my $test = 1;


#playlists <start> <itemsPerResponse> <taggedParameters>

#dir 	Virtual playlist directory, as returned below (dig down).
#search 	Search substring. The search is case insensitive and performed on the item name (song title, directory name or playlist name).
#tags 	Determines which tags are returned. Each returned tag is identified by a letter (see below). The default value is "galdp".

#rescan 	Returned with value 1 if the SlimServer is still scanning the database. The results may therefore be incomplete. Not returned if no scan is in progress.
#count 	Number of results returned by the query.
#  index 	Item index, zero-based. Item delimiter.
#  If item is path: 	
#   item 	Name of the playlist or directory
#    dir 	Virtual playlist directory to dig down into playlist or directory
#  If item is song: 	
#    Tags 	Same tags as defined in command "songinfo".

	
		if(defined $dir){
			@results = eCLIquery(undef, ['playlists', $from, $items, 'tags:', "dir:$dir"]);
		} else {
			@results = eCLIquery(undef, ['playlists', $from, $items, 'tags:']);
		}
		for(my $i = 3; $i < scalar(@results); $i++){	
			$results[$i] =~ /([^:]+):(.*)/;
			
			if(defined $dir && $results[$i] eq "dir:$dir"){
				#skip command
			} elsif($1 eq 'count') {
				if($from == 0) {
					$count = $2;
				}
				if($count == 0 && defined $item){
					$playlists{$item} = 'empty';
				}
			} elsif ($1 eq 'tags') {
			} elsif ($1 eq 'index') {
				$done++;
			} elsif ($1 eq 'item') {
				$newItem = $2;
			} elsif ($1 eq 'dir') {
				$newDir = $2;
				$test = $test && defined $newDir && defined $newItem;
				if($test){
					if(defined $item) {
						$newItem = $item . ':' . $newItem;
					}
					testPlaylist($newItem, $newDir);
					$newItem = undef;
					$newDir = undef;
				} else {
					printf("[playlists] returns one of item/dir\n");
				}
			} elsif ($1 eq 'title') {
				if(!defined $playlists{$item}){
					$playlists{$item} = 'playlist';
				}
			} else {
				printf("[playlists] returns unknown tag: $1\n");
				$test = 0;
			}
		}
		ok($test, "[playlists] returns correct tags");
	}
	
}



# ---------------------------------------------
sub testFlag
{
	my $client = shift;
	my $paramsRef = shift;
	
	my @params1 = @$paramsRef;
	my @params2 = @$paramsRef;
	my @params3 = @$paramsRef;
	my @params4 = @$paramsRef;
	
	my $flag = queryFlag($client, \@params1);

	push @params2, $flag?"0":"1";
	cmd($client, \@params2);

	my $nflag = queryFlag($client, \@params3);
	ok($flag ne $nflag, "enquiring about changed value returns changed value");
	
	push @params4, $flag?"1":"0";
	cmd($client, \@params4);

	return $flag;
}



# ---------------------------------------------
sub queryFlag
{
	my $client = shift;
	my $paramsRef = shift;
	
	my $flag = queryNum($client, $paramsRef);
	ok($flag eq '1' || $flag eq '0', "query returns 0 or 1");
	return $flag;
}

# ---------------------------------------------
sub queryNum
{
	my $client = shift;
	my $paramsRef = shift;
	
	my $num = query($client, $paramsRef);
	ok(($num+0) eq $num, "query returns number");
	return $num;
}

# ---------------------------------------------
sub query
{
	my $client = shift;
	my $paramsRef = shift;
	
	push @$paramsRef, '?';
	
	my @srcparms = @$paramsRef;
	if(defined($client)) {
		unshift(@srcparms, $client);
	}

	my @results = sendCmd($client, $paramsRef);
	
	my $test = (scalar(@results) == scalar(@srcparms));
	
	my $result;
	
	for(my $i = 0; $i < scalar(@results); $i++)
	{
#		print(">$srcparms[$i]<\n");
#		print(">$results[$i]<\n");
		if($srcparms[$i] eq '?')
		{
			$result = $results[$i];
		}
		else
		{
			$test = $test && ($srcparms[$i] eq $results[$i]);
#			print("<$test>\n");
		}
	}
	if(defined($result))
	{
		print("Parsed response result: $result\n");
	}
	else
	{
		print("Parsed response result: <none>\n");
	}
	ok($test && defined($result), 'response has correct grammar and returns value');
	return $result;
}

# ---------------------------------------------
sub query_dual
{
	# Special case for commands taking two ? arguments (display and displaynow)

	my $client = shift;
	my $paramsRef = shift;
	
	push @$paramsRef, '?';
	push @$paramsRef, '?';
	
	my @srcparms = @$paramsRef;
	if(defined($client)) {
		unshift(@srcparms, $client);
	}

	my @results = sendCmd($client, $paramsRef);
	
	# For some reason display ? ? returns both lines in the first argument....
	my $test = (scalar(@results) <= scalar(@srcparms));
	
	my @result;
	
	for(my $i = 0; $i < scalar(@results); $i++)
	{
#		print(">$srcparms[$i]<\n");
#		print(">$results[$i]<\n");
		if($srcparms[$i] eq '?')
		{
			push @result, $results[$i];
		}
		else
		{
			$test = $test && ($srcparms[$i] eq $results[$i]);
#			print("<$test>\n");
		}
	}
#	if(defined(@result))
#	{
		print("Parsed response result:" . join (" ", @result) . "\n");
#	}
#	else
#	{
#		print("Parsed response result: <none>\n");
#	}
	ok($test && scalar @result, 'response has correct grammar and returns values');
	return @result;
}
 # ---------------------------------------------
sub query_Sync
{
	# Special case sync since the command sync ? does not return anything replacing ?
	# if the player is not synced. Should return -, i.e. what needs to be 
	# sent to unsync...
	
	my $client = shift;
	my $paramsRef = shift;
	
	push @$paramsRef, '?';
	
	my @srcparms = @$paramsRef;
	if(defined($client)) {
		unshift(@srcparms, $client);
	}

	my @results = sendCmd($client, $paramsRef);
	
	my $test = 1;
	
	my $numResults = scalar(@results);
	my $result;
	
	for(my $i = 0; $i < $numResults; $i++)
	{
#		print(">$srcparms[$i]<\n");
#		print(">$results[$i]<\n");
		if($srcparms[$i] eq '?')
		{
			$result = $results[$i];
		}
		else
		{
			$test = $test && ($srcparms[$i] eq $results[$i]);
#			print("<$test>\n");
		}
	}
	if (!defined($result))
	{
		$result = "-";
	}
	print("Parsed response result: $result\n");
	ok($test && defined($result), 'response has correct grammar and returns value (sync special case)');
	return $result;
}


# ---------------------------------------------
sub cmd
{
	my $client = shift;
	my $paramsRef = shift;
	
	my @srcparms = @$paramsRef;
	if(defined($client)) {
		unshift(@srcparms, $client);
	}

	my @results = sendCmd($client, $paramsRef);
	
	my $test = (scalar(@results) == scalar(@srcparms));
	
	my $numResults = scalar(@results);
	
	for(my $i = 0; $i < $numResults; $i++)
	{
		$test = $test && ($srcparms[$i] eq $results[$i]);
	}
	ok($test, 'response has correct grammar');
}

# ---------------------------------------------
sub eCLIquery
{
	my $client = shift;
	my $paramsRef = shift;
	
	my @srcparms = @$paramsRef;
	if(defined($client)) {
		unshift(@srcparms, $client);
	}

	my @results = sendCmd($client, $paramsRef);
	
	my $test = (scalar(@results) >= scalar(@srcparms));
#			print("<$test>\n");
		
	for(my $i = 0; $i < scalar(@srcparms); $i++)
	{
		$test = $test && ($srcparms[$i] eq $results[$i]);
#			print("<$test>\n");
	}
			
	my $first = defined($client)?4:3;	
		
	for(my $i = $first; $i < scalar @results; $i++)
	{
		if(!($results[$i] =~ /([^:]+):(.*)/))
		{
			$test = 0;
		}
#			print("<$test>\n");
	}

	ok($test, 'response has correct grammar');
		
	return @results;
}


# ---------------------------------------------
sub sendCmd
{
	my $client = shift;
	my $paramsRef = shift;
	
	my $output;
	my $printoutput;
	my $debugSC = 0;
	
	$printoutput = join("<SP>", @$paramsRef);
	
	foreach my $param (@$paramsRef) {
		$param = uri_escape($param);
	}

	$output = join(" ", @$paramsRef);

	if(defined($client)) {
		$output = uri_escape($client) . " " . $output;
		$printoutput = $client . "<SP>" . $printoutput;
	}
	
	$debugSC && print "::: [$output] -> ";
	print "Request : \"$printoutput\"\n";
	
	print $socket "$output$LF";

	my $answer = <$socket>;

	if (defined($answer))
	{
		$answer =~ s/$CR?$LF/\n/;
		chomp $answer; 
		
		$debugSC && print "[$answer]\n";
			
		my @results = split(" ", $answer);
	
		foreach my $result (@results) {
			$result = uri_unescape($result);
		}
		$printoutput = join("<SP>", @results);
		print "Response: \"$printoutput\"\n";
		return @results;
	}
	print "Response: <disconnected>\n";
	$debugSC && print "\n";
	return undef;
}

# ---------------------------------------------
sub showUsage
{
	print "usage: CLIent.pl <parameters>\n";
	print "\n";
#	print "Mandatory parameter:\n";
#	print "--source=<player name>\ti.e.: \"Sophie\"\n";
#	print "--target=<player name>\ti.e.: \"Suzanne\"\n";
#	print "\n";
	print "Optional parameters:\n";
	print "--server=<ip>\t\tdefault: 127.0.0.1\n";
	print "--port=<nr>\t\tdefault: 9090\n";
	print "--skip=<pdgr>\t\tdefault: <>, i.e. perform all tests\n";
	print "\t\t\tp: skip Players tests\n";
	print "\t\t\td: skip Database tests\n";
	print "\t\t\tg: skip General tests\n";
	print "\t\t\tr: skip Rescan before database tests\n";
	print "\t\t\tExample: --skip=pd to skip players and database tests\n";
#	exit;
}

# ---------------------------------------------
sub showTestTitle
{
	my $title = shift;
	
	print("\n**\n* $title\n**\n");
}

# ---------------------------------------------
# Same routines as SlimServer...

sub filterPrep {
	my $pattern = shift;
	#the following transformations assume that the pattern provided uses * to indicate
	#matching any character 0 or more times, and that . ^ and $ are not escaped
	$pattern =~ s/\\([^\*]|$)/($1 eq "\\")? "\\\\" : $1/eg; #remove single backslashes except those before a *
	$pattern =~ s/([\.\^\$\(\)\[\]\{\}\|\+\?])/\\$1/g; #escape metachars (other than * or \) in $pattern {}[]()^$.|+?
	$pattern =~ s/^(.*)$/\^$1\$/; #add beginning and end of string requirements
	$pattern =~ s/(?<=[^\\])\*/\.\*/g; #replace * (unescaped) with .*
	return qr/$pattern/i;
}

sub filterPats {
	my ($inpats) = @_;
	my @outpats = ();
	foreach my $pat (@$inpats) {
		push @outpats, filterPrep(Slim::Utils::Text::ignoreCaseArticles($pat));
	}
	return \@outpats;
}

sub filter {
	my ($patterns, $const, @items) = @_;
	if (!defined($patterns) || ! @{$patterns}) {
		return @items;
	}

	my @filtereditems;
	# Gross, but this seems to be a relevant optimization.
	if ($const eq '') {
		ITEM: foreach my $item (@items) {
			foreach my $regexpattern (@{$patterns}) {
				if ($item !~ $regexpattern) {
					next ITEM;
				}
			}
			push @filtereditems, $item;
		}
	  } else {
		ITEM: foreach my $item (@items) {
			my $item_const = $item . ' ' . $const;
			foreach my $regexpattern (@{$patterns}) {
				if ($item_const !~ $regexpattern) {
					next ITEM;
				}
			}
			push @filtereditems, $item;
		}
	}

	return @filtereditems;
}

my %caseArticlesMemoize = ();

sub ignorePunct {
	my $s = shift;
	my $orig = $s;
	return undef unless defined($s);
	$s =~ s/[!?,=+<>#%&()\"\'\$\.\\]+/ /g;
	$s =~ s/  +/ /g; # compact multiple spaces, "L.A. Mix" -> "L A Mix", not "L A  Mix"
	$s =~ s/^ +//; # zap leading/trailing spaces.
    $s =~ s/ +$//;
	$s = $orig if ($s eq '');
	return $s;
}

sub matchCase {
	my $s = shift;
	return undef unless defined($s);
	# Upper case and fold latin1 diacritical characters into their plain versions, surprisingly useful.
	$s =~ tr{abcdefghijklmnopqrstuvwxyz¿¡¬√ƒ«»… ÀÃÕŒœ—“”‘’÷Ÿ⁄€‹‡·‚„‰ÂÁËÈÍÎÏÌÓÔÒÚÛÙıˆ˘˙˚¸ˇ˝–}
			{ABCDEFGHIJKLMNOPQRSTUVWXYZAAAAACEEEEIIIINOOOOOUUUUAAAAAACEEEEIIIINOOOOOUUUUYYDD};
	return $s;
}

sub ignoreCaseArticles {
	my $s = shift;
	return undef unless defined($s);
	if (defined $caseArticlesMemoize{$s}) {
		return $caseArticlesMemoize{$s};
	}

	return ($caseArticlesMemoize{$s} = ignorePunct(matchCase($s)));
}

sub clearCaseArticleCache {
	%caseArticlesMemoize = ();
}

