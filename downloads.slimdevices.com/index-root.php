<?php

$v = '8.3.1';

## Array of possible file names to search for
$fileList["/.*\/LogitechMediaServer-$v\.exe/"] = "Logitech Media Server: Windows Executable Installer";
$fileList["/.*\/LogitechMediaServer-$v\-whs.msi/"] = "Logitech Media Server: Windows Home Server Installer";
$fileList["/.*\/LogitechMediaServer-$v\.pkg/"] = "Logitech Media Server: Mac OSX Installer";
// $fileList["/.*\/LogitechMediaServer-$v+\.dmg/"] = "Logitech Media Server: Mac OSX Installer";
$fileList["/.*\/logitechmediaserver-$v\.tgz/"] = "Logitech Media Server: Unix Tarball (i386, x86_64, i386 FreeBSD, ARM EABI, PowerPC)";
$fileList["/.*\/logitechmediaserver-$v-arm-linux\.tgz/"] = "Logitech Media Server: ARM Linux Tarball (ARM EABI)";
$fileList["/.*\/logitechmediaserver-$v\-noCPAN.tgz/"] = "Logitech Media Server: Unix Tarball - No CPAN Libraries";
$fileList["/.*\/logitechmediaserver_${v}_all\.deb/"] = "Logitech Media Server: Debian Installer Package (i386, x86_64, ARM EABI, PowerPC)";
$fileList["/.*\/logitechmediaserver_${v}_amd64\.deb/"] = "Logitech Media Server: Debian Installer Package (x86_64)";
$fileList["/.*\/logitechmediaserver_${v}_arm\.deb/"] = "Logitech Media Server: Debian Installer Package (ARM)";
$fileList["/.*\/logitechmediaserver_${v}_i386\.deb/"] = "Logitech Media Server: Debian Installer Package (i386)";
$fileList["/.*\/logitechmediaserver-$v-1\.noarch\.rpm/"] = "Logitech Media Server: RedHat (RPM) Installer Package";

$changelog = "http://htmlpreview.github.io/?https://raw.githubusercontent.com/Logitech/slimserver/$v/Changelog8.html";
$gitlog = "https://github.com/Logitech/slimserver/commits/$v";

## Print a nice header
print_header($v, $changelog, $gitlog);

print("<TABLE cellpadding=2 cellspacing=2>\n<TH>Version</TH><TH>File</TH><TH>Size (mb)</TH>");

showLatest($v, $fileList);

print("</TABLE>\n");

print_footer();

## showLatest walks through the tree and finds the latest version of each file in the @fileList
function showLatest($version, $fileList) {
	##  Clear out some variables for this pass
	$highestmTime = 0;
	$latestFile = "";
	$searchList = "";
	$prefix = 'LogitechMediaServer_v';

	## Do the find, and find the latest modified file
	$all_downloads = array();
	exec("find ./${prefix}${version} -type f ", $all_downloads);

	## Walk one by one through each file type we're looking for...
	foreach ($fileList as $filere => $filedesc) {
		## Start the table entry
		$pretty_desc = $filedesc;

		## Clear out the mtime
		$fileFound = 0;
		$best_mtime = 0;
		$best_file = "";

		## Now, walk through the array of actual known files
		foreach ($all_downloads as $file) {
			#echo "<br>checking [$filere] against [$file]";

			## If the file name matches the kind we're looking for, then ...
			if (preg_match($filere, $file)) {
				## Set foundFile to 1, just so we know that at least one file of this type was found
				$fileFound = 1;
				## Stat it first to get all the info we need
				$stats = stat($file);
				## Now, check its mTIME vs the best mtime
				if ($stats['mtime'] > $best_mtime) {
					## Rest best_mtime now with the new highest #
					$best_mtime = $stats['mtime'];

					## Set the best matchin file name so far
					$best_file = $file;
				}
			}
		}

		## If no file was found, print error
		if ($fileFound !== 1) {
			#print "<TD>&nbsp;</TD><TD>&nbsp;</TD>";
		} else {
			print("<TR>\n");
			print("<TD align=left>$pretty_desc</TD>\n");
			## Generate a pretty file name
			foreach ((explode("/", $best_file)) as $x) {
				$pretty_file_name = $x;
			}

			$pretty_size = ByteSize($stats['size']);

			## Ok, at this point we have the best match... now print out some pretty HTML for our users
			print("<TD align=left><a href=\"$best_file\">$pretty_file_name</a></TD>\n");
			print("<TD align=center>$pretty_size</TD>\n");
			print("</TR>\n");
		}
	}
}

## Header
function print_header($version, $changelog, $gitlog) {
	print "<HTML><HEAD><TITLE>Logitech Media Server Downloads";
	if ($version) {
		print " - Version $version";
	}
	print "</TITLE></HEAD>\n";
	print "<BODY>\n";
	print "<center>\n";
	print "<h2>Logitech Media Server Downloads";
	if ($version) {
		print " - Version $version";
	}
	print "</h2>\n";
	if ($changelog) {
		print "<p><a href=\"$changelog\">Changelog</a>\n";
		print "<br><a href=\"$gitlog\">Git commit log</a></p>\n";
	}
	print "<hr>\n";
}

function print_footer() {
	print "<p><hr><p><a href=\"nightly/\">Nightly Builds</a></BODY></HTML>";
}

## ByteSize function stolen online... didn't feel like writing my own
function ByteSize($bytes) {
    $size = $bytes / 1024;
    if($size < 1024)
        {
        $size = number_format($size, 2);
        $size .= ' KB';
        }
    else
        {
        if($size / 1024 < 1024)
            {
            $size = number_format($size / 1024, 2);
            $size .= ' MB';
            }
        else if ($size / 1024 / 1024 < 1024)
            {
            $size = number_format($size / 1024 / 1024, 2);
            $size .= ' GB';
            }
        }
    return $size;
}

