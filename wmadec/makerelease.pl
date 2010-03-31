#!/usr/bin/perl -w

no warnings 'portable';

use strict;
use Getopt::Long;
use File::Spec::Functions qw(:ALL);

my $command = "build";
my $debug = 0;
my $wmsdkpath;

if (!GetOptions(
	'wmsdkpath=s'		=> \$wmsdkpath,
	'command=s' 	=> \$command,
	'debug'   		=> \$debug,
)) {
	showUsage();
	exit(1);
};

my $incdir;
my $libdir;
if (defined($wmsdkpath)) {
	$incdir = catdir($wmsdkpath, "include");
	$libdir = catdir($wmsdkpath, "lib");
	if (!-d $wmsdkpath ||
		!-d $incdir ||
		!-d $libdir) {
		print "Can't find WMSDK9 directory\n";
		exit(1);
	}
}

my $objdir;
if ($debug) {
    $objdir = "Debug";
}
else {
    $objdir = "Release";
}

if (defined($incdir)) {
	print "Creating wmadec VC Project...\n";
	open TEMPLATE, "wmadec.vctmpl" or die "Couldn't open project template ($!)\n";
	open PROJ, ">wmadec.vcproj" or die "Couldn't open VC project for writing ($!)\n";
	while (<TEMPLATE>) {
		s/AdditionalIncludeDirectories="(.*)"/AdditionalIncludeDirectories="$incdir"/;
		s/AdditionalLibraryDirectories="(.*)"/AdditionalLibraryDirectories="$libdir"/;
		print PROJ $_;
	}
}

print "Building wmadec tool...\n";
system "devenv wmadec.sln /$command $objdir";

sub showUsage {
    print "makerelease.pl [--debug] [--command COMMAND] --wmsdkpath WMSDKPATH\n";
    print "\t--debug - Native components will be built with debugging information.\n";
    print "\t--command COMMAND - The build command to use for native components (\"build\" by default).\n";
    print "\t--wmsdkpath WMSDKPATH - The location of the Windows Media SDK.\n";
}

# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# End:
