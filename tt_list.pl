#! /usr/bin/perl -w
use strict;

use File::Spec::Functions qw(catfile catdir);
use File::Path qw(mkpath);

sub fixtemplate {
	my $templateref = shift;
	my %seen = ();

	while ($$templateref =~ m,\[\% (\S+) \%\],g) {
		next if ($1 eq 'END' || $1 eq 'ELSE');

		print "    $1\n" unless $seen{$1}++ || $1 eq '';
	}
	
	return $templateref;
}

sub processDir {
	my ($dir,$dirref) = @_;
	opendir(DIR,$dir) or die "Cannot open directory $dir\n";

	my @subNames = readdir(DIR);
	closedir(DIR);
	print "\nProcessing $dir\n";
	
	foreach my $file (@subNames) {
		next if ($file eq ".");
		next if ($file eq "..");
		next if ($file eq "CVS");

		$file = catfile($dir,$file);
		next unless (-d $file || $file =~ /\.(?:htm|js)/i);

		print "\n  $file\n";

		if (-d $file) {
			push @$dirref, $file;
		} elsif (($file =~ /\.htm/i) || ($file =~ /\.js/i)) {

			open(FILE, $file) or die "can't open $file";

			my $contents;
			read (FILE, $contents, -s FILE);
			close FILE;
			fixtemplate(\$contents);
		}
	}
}

my @dirs = ();
my $rootdir = shift @ARGV || '.';
push @dirs, $rootdir;

for (my $i = 0; $i <= $#dirs; $i++) {
	processDir($dirs[$i],\@dirs);
}
