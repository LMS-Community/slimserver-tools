#! /usr/bin/perl -w
# test change
use strict;

use File::Spec::Functions qw(catfile catdir);
use File::Path qw(mkpath);

sub fixtemplate {
	my $templateref = shift;
	while ($$templateref =~ s{\[EVAL\](.*?)\[/EVAL\]}{<!-- EVAL PLACEHOLDER -->}s) {
		print "EVAL encountered, manual intervention required.\n";
		my $evaltext = $1;
		#perl code frequently includes braces and square brackets,
		#which will confuse the following replacements.
		$evaltext =~ s/{/&lbrc;/sg;
		$evaltext =~ s/}/&rbrc;/sg;
		$evaltext =~ s/\[/&lsqb;/sg;
		$evaltext =~ s/\]/&rsqb;/sg;
		$$templateref =~ s{<!-- EVAL PLACEHOLDER -->}
				 {<!-- \[ EVAL \]$evaltext\[ /EVAL \] -->}s;
	}
	while ($$templateref =~ s{\[S\s+([^\[\]]+)\]}{<!-- STRING PLACEHOLDER -->}s) {
		my $stringtext = $1;
		my $outstring = '';
		my $extrafilt;
		my ($left,$mid,$right) = $stringtext =~ m/^([^{}]+)?(?:{(.+)})?(.*?)$/;
		$outstring .= '"' . $left . '"' if (defined $left && $left gt '');
		if (defined $mid) {
			$outstring .= ' _ ' if (defined $left && $left gt '' && $mid gt '');
			if ($mid =~ s/^([&%])//) {$extrafilt = ($1 eq '&') ? 'html' : 'uri';};
			$outstring .= $mid if $mid gt '';
		}
		if (defined $right) {
			$outstring .= ' _ ' if ($outstring gt '' && $right gt '');
			$outstring .= '"' . $right . '"' if $right gt '';
		}
		$outstring .= ' | ' . $extrafilt if defined $extrafilt;
		$$templateref =~ s{<!-- STRING PLACEHOLDER -->}{\[\% $outstring | string \%\]}s;
	}
	$$templateref =~ s{\[SET\s+([^\[\] ]+)\s+(.+?)\](?!\])}
			  {\[\% $1 = \'$2\' \%\]}sg;
	$$templateref =~ s{\[IF\s+([^\[\]]+)\](.*?)\[/IF\]}
			  {\[\% IF $1 \%\]$2\[\% END \%\]}sg;
	$$templateref =~ s{\[IFN\s+([^\[\]]+)\](.*?)\[/IFN\]}
			  {\[\% IF not $1 \%\]$2\[\% END \%\]}sg;
	my %comptype = ( 'EQ' => '==', 'NE' => '!=', 'GT' => '>', 'LT' => '<');
	while ($$templateref =~ s{\[(EQ|NE|GT|LT)\s+([^\[\]]+)\s+(.+?)\](?!\])(.*?)\[/\1\]}
			  {\[\% IF $2 $comptype{$1} \'$3\' \%\]$4\[\% END \%\]}sg) {}
	$$templateref =~ s{\[INCLUDE\s+([^\[\]]+)\]}
			  {\[\% PROCESS $1 \%\]}sg;
	$$templateref =~ s{\[STATIC\s+([^\[\]]+)\]}
			  {\[\% INSERT $1 \%\]}sg;
	$$templateref =~ s{\[NB\](.+?)\[\/NB\]}
			  {\[\% FILTER nbsp \%\]$1\[\% END \%\]}sg;
	$$templateref =~ s{\[E\](.+?)\[\/E\]}
			  {\[\% FILTER uri \%\]$1\[\% END \%\]}sg;
	$$templateref =~ s/{%([^{}]+)}/\[\% $1 | uri \%\]/g;
	$$templateref =~ s/{&([^{}]+)}/\[\% $1 | html \%\]/g;
	$$templateref =~ s/{([^{}]+)}/\[\% $1 \%\]/g;
	#correct for strings and variables embedded in SET directives
	$$templateref =~ s{\[\% (\S+) = \'\[\% (.+?) \%\]\' \%\]}
			  {\[\% $1 = $2 \%\]}sg;
	my $tempindex = 0;
	#correct for strings and variables embedded in comparison directives
	while ($$templateref =~ s{\[\% IF (\S+) (\S+) \'\[\% (.+?) \%\]\' \%\]}
				 {\[\% temp.$tempindex = $3; IF $1 $2 temp.$tempindex \%\]}s) {
		$tempindex++;
	}
	$$templateref =~ s/&lsqb;/\[/g;
	$$templateref =~ s/&rsqb;/\]/g;
	$$templateref =~ s/&lbrc;/{/g;
	$$templateref =~ s/&rbrc;/}/g;
	return $templateref;
}

sub fixinclude {
	my $templateref = shift;
	$$templateref =~ s/\[\% (\S+) = (\S+) \%\]/\[\% params\.$1 = $2 \%\]/sg;
	return $templateref;
}

sub processDir {
	my ($dir,$dirref,$olddir) = @_;
	opendir(DIR,$dir) or die "Cannot open directory $dir\n";
	my @subNames = readdir(DIR);
	closedir(DIR);
	if (! -e catdir($olddir,$dir)) { mkpath(catdir($olddir,$dir)) or die "can't create ".catdir($olddir,$dir)};
	foreach my $file (@subNames) {
		next if ($file eq ".");
		next if ($file eq "..");
		next if ($file eq "CVS");
		$file = catfile($dir,$file);
		next unless (-d $file || $file =~ /\.(?:htm|js)/i);
		print "Processing: $file\n";
		if (-d $file) {
			push @$dirref, $file;
		} elsif (($file =~ /\.htm/i) || ($file =~ /\.js/i)) {
			my $outfile = catfile($olddir,$file);
			#print "$file to $outfile\n";
			rename ($file, $outfile);
			open(FILE, $outfile) or die "can't open $outfile";
			open(OUTFILE, ">$file") or die "can't open $file";
			my $contents;
			read (FILE, $contents, -s FILE);
			close FILE;
			fixtemplate(\$contents);
			if ($file =~ /include\.htm.?$/) {
				fixinclude(\$contents);
			}
			binmode OUTFILE;
			print OUTFILE $contents;
			close OUTFILE;
		}
	}
}

my @dirs = ();
my $rootdir = shift @ARGV || '.';
push @dirs, $rootdir;
my $olddir = shift @ARGV || 'old';
if (! -e $olddir) { mkdir $olddir};
if (! -e catdir($olddir,$rootdir)) { mkpath(catdir($olddir,$rootdir)) or die "can't create ".catdir($olddir,$rootdir)};
for (my $i = 0; $i <= $#dirs; $i++) {
	processDir($dirs[$i],\@dirs,$olddir);
}
