#!/usr/bin/perl -w
# 
# Translates slimp3 skins from Slimp3 Server 4.2.2 and before to 
# new format for Slimserver 5.0 and beyond.
#
# Renames slimp3.css to slimserver.css and edits all html files
# for perl module references and css references.
#
# old html files are stored in directory named "old", created in 
# directory from which skinjob.pl is run
#
# USAGE:  skinjob.pl <skinname>
# where <skinname> is optional.  It needs to point to the folder location for the skin you wish to change. 
# If argument is not given, current directory will be used. Run skinjob.pl from the HTML dir and it will convert all skins.
#
use File::Spec::Functions qw(catfile catdir);
use File::Path qw(mkpath);

my %convertlist =	(
	"SliMP3::Buttons" =>			"Slim::Buttons",
	"SliMP3::Animation" =>		"Slim::Display::Animation",
	"SliMP3::CLI" =>				"Slim::Control::CLI",
	"SliMP3::Command" =>			"Slim::Control::Command",
	"SliMP3::Stdio" =>			"Slim::Control::Stdio",
	"SliMP3::Animation" =>		"Slim::Display::Animation",
	"SliMP3::Display::update.(.*?).;"	=> "->update();",
	"SliMP3::Display" =>			"Slim::Display::Display",
	"SliMP3::AIFF" =>				"Slim::Formats::AIFF",
	"SliMP3::Movie" =>			"Slim::Formats::Movie",
	"SliMP3::Ogg" =>				"Slim::Formats::Ogg",
	"SliMP3::Parse" =>			"Slim::Formats::Parse",
	"SliMP3::Wav" =>				"Slim::Formats::Wav",
	"SliMP3::Decoder" =>			"Slim::Hardware::Decoder",
	"SliMP3::IR" =>				"Slim::Hardware::IR",
	"SliMP3::VFD" =>				"Slim::Hardware::VFD",
	"SliMP3::i2c" =>				"Slim::Hardware::i2c",
	"SliMP3::mas3507d" =>		"Slim::Hardware::mas3507d",
	"SliMP3::mas35x9" =>			"Slim::Hardware::mas35x9",
	"SliMP3::Info" =>				"Slim::Music::Info",
	"SliMP3::MoodLogic" =>		"Slim::Music::MoodLogic",
	"SliMP3::MusicFolderScan" =>	"Slim::Music::MusicFolderScan",
	"SliMP3::iTunes" =>				"Slim::Music::iTunes",
	"SliMP3::mDNS" =>					"Slim::Networking::mDNS",
	"SliMP3::Client" =>				"Slim::Player::Client",
	"SliMP3::Control::volume.(.*?),(.*?).;" =>		"->volume(",
	"SliMP3::Control::treble.(.*?),(.*?).;" =>		"->treble(",
	"SliMP3::Control::bass.(.*?),(.*?).;" =>			"->bass(",
	"SliMP3::Control::fade_volume.(.*?),(.*?).;" =>	"->fade_volume(",
	"SliMP3::Control::mute.(.*?).;" =>					"->mute();",
	"SliMP3::Control::mute" =>								"$client->mute",
	"SliMP3::Control::play.(.*?),(.*?).;" =>			"->play(",
	"SliMP3::Control::stop.(.*?).;" =>					"->stop();",
	"SliMP3::Control::resume.(.*?).;" =>				"->resume();",
	"SliMP3::Control::pause.(.*?).;" =>					"->pause();",
	"SliMP3::Control::playout.(.*?).;" =>				"->playout();",
	"SliMP3::Control::maxVolume" =>		"Slim::Player::Client::maxVolume",
	"SliMP3::Control::maxTreble" =>		"Slim::Player::Client::maxTreble",
	"SliMP3::Control::minTreble" =>		"Slim::Player::Client::minTreble",
	"SliMP3::Control::maxBass" =>			"Slim::Player::Client::maxBass",
	"SliMP3::Control::minBass" =>			"Slim::Player::Client::minBass",
	"SliMP3::Discovery" =>			"Slim::Networking::Discovery",
	"use SliMP3::Playlist"	=>		"use Slim::Player::Playlist;\nuse Slim::Player::Source;\nuse Slim::Player::Sync",
	"SliMP3::Playlist::syncname"	=>	"Slim::Player::Sync::syncname",
	"SliMP3::Playlist::syncwith"	=>	"Slim::Player::Sync::syncwith",
	"SliMP3::Playlist::unsync"	=>		"Slim::Player::Sync::unsync",
	"SliMP3::Playlist::sync"	=>		"Slim::Player::Sync::sync",
	"SliMP3::Playlist::saveSyncPrefs"	=>	"Slim::Player::Sync::saveSyncPrefs",
	"SliMP3::Playlist::restoreSync"	=>	"Slim::Player::Sync::restoreSync",
	"SliMP3::Playlist::syncedWith"	=>	"Slim::Player::Sync::syncedWith",
	"SliMP3::Playlist::isSyncedWith"	=>	"Slim::Player::Sync::isSyncedWith",
	"SliMP3::Playlist::canSyncWith"	=>	"Slim::Player::Sync::canSyncWith",
	"SliMP3::Playlist::checkSync"	=>	"Slim::Player::Sync::checkSync",
	"SliMP3::Playlist::isMaster"	=>	"Slim::Player::Sync::isMaster",
	"SliMP3::Playlist::master"	=>		"Slim::Player::Sync::master",
	"SliMP3::Playlist::slaves"	=>		"Slim::Player::Sync::slaves",
	"SliMP3::Playlist::isSlave"	=>	"Slim::Player::Sync::isSlave",
	"SliMP3::Playlist::masterOrSelf"	=>	"Slim::Player::Sync::masterOrSelf",
	"SliMP3::Playlist::isSynced"	=>	"Slim::Player::Sync::isSynced",
	"SliMP3::Playlist::rate"	=>		"Slim::Player::Source::rate",
	"SliMP3::Playlist::songTime"	=>	"Slim::Player::Source::songTime",
	"SliMP3::Playlist::songRealPos"	=>	"Slim::Player::Source::songRealPos",
	"SliMP3::Playlist::playmode"	=>	"Slim::Player::Source::playmode",
	"SliMP3::Playlist::lastChunk"	=>	"Slim::Player::Source::lastChunk",
	"SliMP3::Playlist::nextChunk"	=>	"Slim::Player::Source::nextChunk",
	"SliMP3::Playlist::gototime"	=>	"Slim::Player::Source::gototime",
	"SliMP3::Playlist::jumpto"	=>		"Slim::Player::Source::jumpto",
	"SliMP3::Playlist::openNext"	=>	"Slim::Player::Source::openNext",
	"SliMP3::Playlist::currentSongIndex"	=>	"Slim::Player::Source::currentSongIndex",
	"SliMP3::Playlist::closeSong"	=>	"Slim::Player::Source::closeSong",
	"SliMP3::Playlist::openSong"	=>	"Slim::Player::Source::openSong",
	"SliMP3::Playlist::readNextChunk"	=>	"Slim::Player::Source::readNextChunk",
	"SliMP3::Playlist::pauseSynced"	=>	"Slim::Player::Source::pauseSynced",
	"SliMP3::Playlist::count"	=>			"Slim::Player::Playlist::count",
	"SliMP3::Playlist::song"	=>			"Slim::Player::Playlist::song",
	"SliMP3::Playlist::shuffleList"	=>	"Slim::Player::Playlist::shuffleList",
	"SliMP3::Playlist::playList"	=>		"Slim::Player::Playlist::playList",
	"SliMP3::Playlist::shuffle"	=>		"Slim::Player::Playlist::shuffle",
	"SliMP3::Playlist::repeat"	=>			"Slim::Player::Playlist::repeat",
	"SliMP3::Playlist::copyPlaylist"	=>	"Slim::Player::Playlist::copyPlaylist",
	"SliMP3::Playlist::removeTrack"	=>	"Slim::Player::Playlist::removeTrack",
	"SliMP3::Playlist::removeMultipleTracks"	=>	"Slim::Player::Playlist::removeMultipleTracks",
	"SliMP3::Playlist::forgetClient"	=>	"Slim::Player::Playlist::forgetClient",
	"SliMP3::Playlist::refreshPlaylist"	=>	"Slim::Player::Playlist::refreshPlaylist",
	"SliMP3::Playlist::moveSong"	=>	"Slim::Player::Playlist::moveSong",
	"SliMP3::Playlist::clear"	=>		"Slim::Player::Playlist::clear",
	"SliMP3::Playlist::fischer_yates_shuffle"	=>	"Slim::Player::Playlist::fischer_yates_shuffle",
	"SliMP3::Playlist::reshuffle"	=>	"Slim::Player::Playlist::reshuffle",
	"SliMP3::Playlist::executecommand"	=>	"Slim::Player::Playlist::executecommand",
	"SliMP3::Playlist::setExecuteCommandCallback"	=>	"Slim::Player::Playlist::setExecuteCommandCallback",
	"SliMP3::Playlist::clearExecuteCommandCallback"	=>	"Slim::Player::Playlist::clearExecuteCommandCallback",
	"SliMP3::Playlist::modifyPlaylistCallback"	=>	"Slim::Player::Playlist::modifyPlaylistCallback",
	"SliMP3::Protocol" =>		"Slim::Networking::Protocol",
	"SliMP3::Stream" =>			"Slim::Networking::Stream",
	"SliMP3::Misc" =>				"Slim::Utils::Misc",
	"SliMP3::OSDetect" =>		"Slim::Utils::OSDetect",
	"SliMP3::Prefs" =>			"Slim::Utils::Prefs",
	"SliMP3::Scan" =>				"Slim::Utils::Scan",
	"SliMP3::Scheduler" =>		"Slim::Utils::Scheduler",
	"SliMP3::Strings" =>			"Slim::Utils::Strings",
	"SliMP3::Timers" =>			"Slim::Utils::Timers",
	"SliMP3::HTTP" =>				"Slim::Web::HTTP",
	"SliMP3::History" =>			"Slim::Web::History",
	"SliMP3::Olson" =>			"Slim::Web::Olson",
	"SliMP3::Pages" =>			"Slim::Web::Pages",
	"SliMP3::RemoteStream" =>	"Slim::Web::RemoteStream",
	"SliMP3::Setup" =>			"Slim::Web::Setup"
	);
	
@ARGV = qw(.) unless @ARGV;
my $dir = pop(@ARGV);
my $pwd = qw(.);	
opendir(DIR,$dir) or die "Cannot open directory $_\n";
my @fileNames = readdir(DIR);
closedir(DIR);
if (! -e "old") { mkdir "old"};
if (! -e catdir("old",$dir)) { mkpath(catdir("old",$dir)) or die "can't create ".catdir("old",$dir)};
if ($dir ne ".") {
	$pwd = catdir($pwd,$dir);
}
foreach my $file (@fileNames) {
	next if ($file eq ".");
	next if ($file eq "..");
	next if ($file =~ /.gif/);
	next if ($file =~ /.jpg/);
	next if ($file =~ /.old/);
	$file = catfile($dir,$file);
	print "$file\n";
	if (-d $file) {
		doSub($file);
	}
	my $outfile;
	if ($file eq catfile($dir,"slimp3.css")) {
		$outfile = catfile($pwd,"slimserver.css");
		rename ($file, $outfile);
	} elsif (($file =~ /\.html/i) || ($file =~ /\.js/i)) {
		$outfile = catfile("old",$file);
		print "$file to $outfile\n";
		rename ($file, $outfile);

		open(FILE, $outfile) or die "can't open $outfile";
		open(OUTFILE, ">$file") or die "can't open $file";
		while ($line = <FILE>) {	
			foreach my $tag (keys %convertlist) {
				if ($line =~ m/$tag/i) {
					if (defined($1)) {
						if (defined($2)) {
							$line =~ s/$tag/$1.$convertlist{$tag}.$2.");"/ge;
						} else {
							$line =~ s/$tag/$1.$convertlist{$tag}/ge;
						}
					} else  {$line =~ s/$tag/$convertlist{$tag}/ge;}
					# $tag,$convertlist{$tag} => $line\n";
				}
			}
			print OUTFILE $line;
		}
		close FILE;
		close OUTFILE;
	}
}

sub doSub {
	my $dir = shift;
	opendir(DIR,$dir) or die "Cannot open directory $dir\n";
	my @subNames = readdir(DIR);
	closedir(DIR);
	if (! -e catdir("old",$dir)) { mkpath(catdir("old",$dir)) or die "can't create ".catdir("old",$dir)};
	foreach my $file (@subNames) {
		next if ($file eq ".");
		next if ($file eq "..");
		next if ($file =~ /.gif/);
		next if ($file =~ /.jpg/);
		next if ($file =~ /.old/);
		$file = catfile($dir,$file);
		print "sub: $file\n";
		if (-d $file) {
			doSub($file);
		}
		if ($file eq catfile($dir,"slimp3.css")) {
			
			rename ($file, catfile($dir,"slimserver.css"));
		} elsif (($file =~ /\.html/i) || ($file =~ /\.js/i)) {
			$outfile = catfile("old",$file);
			#print "$file to $outfile\n";
			rename ($file, $outfile);
	
			open(FILE, $outfile) or die "can't open $outfile";
			open(OUTFILE, ">$file") or die "can't open $file";
			while ($line = <FILE>) {	
				foreach my $tag (keys %convertlist) {
					if ($line =~ m/$tag/i) {
						if (defined($1)) {
							if (defined($2)) {
								$line =~ s/$tag/$1.$convertlist{$tag}.$2.");"/ge;
							} else {
								$line =~ s/$tag/$1.$convertlist{$tag}/ge;
							}
						} else  {$line =~ s/$tag/$convertlist{$tag}/ge;}
						# $tag,$convertlist{$tag} => $line\n";
					}
				}
				print OUTFILE $line;
			}
			close FILE;
			close OUTFILE;
		}
	}
}
