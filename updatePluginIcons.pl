#!/usr/bin/perl

#
# Script to copy icons from MasterIcons directory to SqueezeCenter plugins directory
#
# 1. requires directory for SC Plugins as 1st command line arg
# 2. requires directory for MasterIcons folder as 2nd command line arg
#
# finds icons in MasterIcons folder area and copies to the correct path in the plugin directory of SC
#
# bklaas 06.09

use strict;
use File::Copy;

my $pluginIconMap = {
	Amazon	=>	'icon_amazon_store.png',
	AppGallery =>   'icon_app_gallery.png',
	Classical =>	'icon_classicaldotcom_C.png',
	Deezer =>	'icon_deezer.png',
	DigitalInput =>	'icon_digital_inputs.png',
	InfoBrowser =>	'icon_news_ticker.png',
	LastFM =>	'icon_lastfm.png',
	LineIn =>	'icon_linein.png',
	# FIXME: no icon in masterIcons folder for line out
	#LineOut =>	'???',
	Live365 =>	'icon_live365.png',
	LMA =>		'icon_LMA.png',
	Mediafly =>	'icon_Mediafly.png',
	MP3tunes =>	'icon_MP3tunes.png',
	MusicMagic =>	'icon_music_ip.png',
	MyApps =>       'icon_my_apps.png',
	Napster =>	'icon_napster.png',
	Pandora =>	'icon_pandora_P.png',
	# note: the filename typo below is in svn, it's not a typo here
	Podcast =>	'icon_Pocast_services.png',
	# FIXME: no icon in masterIcons folder for random play
	#RandomPlay =>	'???',
	RhapsodyDirect =>	'icon_rhapsody.png',
	Sirius =>	'icon_sirius.png',
	Slacker =>	'icon_slacker.png',
	Sounds =>	'icon_nature_sounds.png',
};



my $pluginDir = $ARGV[0];
my $iconDir   = $ARGV[1];

if ( ! -d $pluginDir || ! -d $iconDir ) {
	die "usage: updatePluginIcons.pl <SC plugin dir> <Master icons dir>";
}

for my $plugin ( sort keys %$pluginIconMap ) {
	# if icon in $iconDir exists, copy it to associated 
	my $scIconPath = "HTML/EN/plugins/$plugin/html/images";
	my $pluginIconPath = $pluginDir . "/" . $plugin . "/" . $scIconPath;
	my $masterIcon = $iconDir . '/' . $pluginIconMap->{$plugin};
	if ( ! -d $pluginIconPath ) {
		print "No directory found at: " . $pluginIconPath . "\n";
		next;
	}
	if ( ! -e $masterIcon ) {
		print "no icon found in master icon dir at: " . $masterIcon . "\n";
exit;
	}

	# if we go here, let's copy it
	print "Copying $masterIcon to $pluginIconPath/icon.png\n";
	copy($masterIcon, "$pluginIconPath/icon.png");
	
}

create_svk_file($pluginDir);

sub create_svk_file {
	my $dir = shift;

	my $prog = "svk status $dir";
	my @commands = ();
	open(PROG, "$prog |");
	while(<PROG>) {
		s/^\?\s+/svk add /;
		s/^\!\s+/svk remove /;
		if (/^svk/ && /icon\.png/ ) {
			print "adding this to svk file: ";
			push @commands, $_;
		}
		print;
	}
	close(PROG);

	if ($commands[0]) {
		open(OUT, ">svkUpdate.bash");
		print OUT "#!/bin/bash\n\n";
		for (@commands) {
			print OUT $_;
		}
		close(OUT);
	}
}
