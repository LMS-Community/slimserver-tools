#! /usr/bin/perl -w

# Update the strings.txt file from the SlimServer project.
#
# Reads the strings.txt file and checks all items for the 
# presence of an entry defined in $language.
# If such an entry is not present, it displays entries that are
# defined in @display and asks the input for $language.
#
# An additional sort is done on all translation strings 
# (e.g. DE, FR, EN --> DE, EN, FR) 
#
# L. Hollevoet
#

$language = "NO";                  # language to update
@display  = ("EN", "DE", "FR");    # display these languages as 'hints'

# Open input and output files
open (INPUT, "<strings.txt") || die "Could not open strings.txt";
open (OUTPUT,">out.txt") || die "Could not open output.txt";

# Process the input file
while ($line = <INPUT>){

    # copy comments blindly, they begin with #
    if ($line =~ /^\#/){ 
	print OUTPUT $line;
	next; 
    }

    # search for an item, this begins with a capital
    if ($line =~ /^([A-Z].+)/){
	$item = $1;
    }

    # grab the contents of an entry, format: tab, XX, tab, string with XX=language 
    if ($line =~ /^\s([A-Z]{2})\s(.+)/){
	# language identifier in $1
	# translated string in $2

	# Do a check on multiple declarations of a language string under one item
	# In case it occurs, print a warning and keep the last occurrence
	if (defined $entries{$1}){
	    print "WARNING: more than one '$1' in $item\n";
	}

	$entries{$1} = $2;
    }

    # if an empty line is encountered, check if something has to be written to the
    # output file. Make sure to also recognise empty lines containing multiple tabs
    if ($line =~ /^\s+$/){
	if (defined %entries){
	    update_item();
	    print_item();
	    undef %entries;
	} else {
	    print OUTPUT "\n";
	}
    }
}

# Close files
close(INPUT);
close(OUTPUT);

# This sub will display the defined languages in @display and ask for 
# the translated input for language $language 
# If the user gives an empty line, then skip the addition
sub update_item {
    if (not defined $entries{$language}){
	# if we get here the $language entry was not defined in the item
	print "Item: $item\n";
	foreach $lang (@display){
	    if (defined $entries{$lang}){
		print "\t$lang\t$entries{$lang}\n";
	    }
	}
	print "\t$language\t";
	chomp ($input = <STDIN>);

	if ($input ne ""){
	    $entries{$language} = $input;
	}

    }
}

# This sub writes an item to the output file
sub print_item {
    print OUTPUT "$item\n";
    foreach $entry (sort keys %entries){
	print OUTPUT "\t$entry\t$entries{$entry}\n";
    }
    print OUTPUT "\n";
}
