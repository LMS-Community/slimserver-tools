#!/usr/bin/perl
#
# resize-icons.pl [path] [spec]
# Resize all icon.png files found to the given spec

use strict;
use FindBin;

use constant RESIZER => 1;

use lib (
	"$FindBin::Bin/../server",
	"$FindBin::Bin/../server/CPAN",
	"$FindBin::Bin/../server/CPAN/arch/5.10/darwin-thread-multi-2level",
);

use File::Next;
use File::Spec::Functions qw(catfile);
use Slim::Utils::GDResizer;

my $path = shift || die "No path found";
my $spec = shift || die "No spec found";

my $files = File::Next::files( {
	file_filter => sub { /icon\.png/ },
}, $path );

my ($width, $height, $mode) = $spec =~ /^([^x]+)x([^_]+)_(\w)$/;

while ( my $file = $files->() ) {
	my ($ref, $format) = Slim::Utils::GDResizer->resize(
		file   => $file,
		width  => $width,
		height => $height,
		mode   => $mode,
	);
	
	if ( $ref ) {
		my $outfile = $file;
		$outfile =~ s/\.png$/_${spec}.png/;
		
		open my $fh, '>', $outfile or die "Cannot open $outfile: $!";
		print $fh $$ref;
		close $fh;
		
		print $file . "\n";
	}
}