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
	"SliMP3::Display" =>			"Slim::Display::Display",
	"SliMP3::AIFF" =>			"Slim::Formats::AIFF",
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
	"SliMP3::Info" =>			"Slim::Music::Info",
	"SliMP3::MoodLogic" =>		"Slim::Music::MoodLogic",
	"SliMP3::MusicFolderScan" =>	"Slim::Music::MusicFolderScan",
	"SliMP3::iTunes" =>			"Slim::Music::iTunes",
	"SliMP3::mDNS" =>			"Slim::Networking::mDNS",
	"SliMP3::Client" =>			"Slim::Player::Client",
	"SliMP3::Control" =>			"Slim::Player::Control",
	"SliMP3::Discovery" =>		"Slim::Networking::Discovery",
	"SliMP3::Playlist" =>		"Slim::Player::Playlist",
	"SliMP3::Protocol" =>		"Slim::Networking::Protocol",
	"SliMP3::Stream" =>			"Slim::Networking::Stream",
	"SliMP3::Misc" =>			"Slim::Utils::Misc",
	"SliMP3::OSDetect" =>		"Slim::Utils::OSDetect",
	"SliMP3::Prefs" =>			"Slim::Utils::Prefs",
	"SliMP3::Scan" =>			"Slim::Utils::Scan",
	"SliMP3::Scheduler" =>		"Slim::Utils::Scheduler",
	"SliMP3::Strings" =>			"Slim::Utils::Strings",
	"SliMP3::Timers" =>			"Slim::Utils::Timers",
	"SliMP3::HTTP" =>			"Slim::Web::HTTP",
	"SliMP3::History" =>			"Slim::Web::History",
	"SliMP3::Olson" =>			"Slim::Web::Olson",
	"SliMP3::Pages" =>			"Slim::Web::Pages",
	"SliMP3::RemoteStream" =>	"Slim::Web::RemoteStream",
	"SliMP3::Setup" =>			"Slim::Web::Setup",
	"slimp3.css" =>				"slimserver.css"
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
		while (my $line = <FILE>) {	
			foreach my $tag (keys %convertlist) {
				$line =~ s/$tag/$convertlist{$tag}/ge;		
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
			while (my $line = <FILE>) {	
				foreach my $tag (keys %convertlist) {
					$line =~ s/$tag/$convertlist{$tag}/ge;		
				}
				print OUTFILE $line;
			}
			close FILE;
			close OUTFILE;
		}
	}
}
