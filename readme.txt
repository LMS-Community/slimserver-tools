SqueezeCenter Tools

This directory contains several scripts to work along with the slimserver software.

-skinjob.pl
	Use this tool to convert skins made for SLIMP3 Server (versions before 5.0).  The syntax is 
	as follows:
	skinjob.pl <skinname> where skinname is an optional argument for the skin you wish to change.  
	If no argument, it will start with the current directory.  If you run this from the root 
	directory of the skin, it will convert that skin without any arguments needed.  This script
	replaces slimp3.css with slimserver.css, all references within the html file to 
	slimserver.css, and converts any perl module calls to the new SlimServer modules.  
	Old html files are copied and saved to a directory named "old".

-slimp3.pl
	Command line interface access to the SlimServer.
	Usage: slimp3.pl --httpaddr <host|ip> --httpport <port> --command <command> 
          [--p1 <arg>] [--p2 <arg>] [--p3 <arg>] [--p4 <arg>] [--player <playerid>]

	--httpaddr  => The hostname or ip address of the SLIMP3 web server
	--httpport  => The port on which the SLIMP3 web server is listening
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

-update_strings.pl
	Reads the strings.txt file and checks all items for the presence of an entry defined in 
	$language.  If such an entry is not present, it displays entries that are defined in 
	@display and asks the input for $language.
	An additional sort is done on all translation strings 
	(e.g. DE, FR, EN --> DE, EN, FR) 
	Result is stored in out.txt

-whack.pl
	Use this tool to convert old plugins (made for SLIMP3 Server versions below 5.0) to 
	SlimServer plugins.  The syntax for the command is as follows:
	whack.pl myplugin.pm...
	This will rewrite myplugin.pm (and any other specified files), leaving
	a copy of the script in myplugin.pm.old, to use the new module layout.

-strings 
	a few tools to extract/merge strings for localization by SLT