#!/usr/bin/perl
# cl2html.pl - Convert the XML output of cvs2cl.pl to (X)HTML

# Copyright (C) 2003 Anderson Lizardo
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA

# $Id: cl2html.pl,v 1.1 2004/09/20 21:54:01 dean Exp $

use strict;
use warnings;

use XML::Parser;
use Getopt::Long;
use Pod::Usage;
use POSIX qw(strftime);

# Output only the last $entries_limit CVS changes
my $entries_limit = 2000;

# Convert ISO 8601 date (yyyy-mm-dd) to the specified format
sub isodate2any {
    my ($date, $format) = @_;
    if ($date =~ /(\d{4})-(\d{2})-(\d{2})/) {
        return strftime($format, 0, 0, 0, $3, $2 - 1, $1 - 1900);
    }
    else {
        return undef;
    }
}

my $help = 0;
my $man = 0;
my $infile = "";
my $with_filename = 0;

GetOptions(
    "help" => \$help,
    "man" => \$man,
    "infile=s" => \$infile,
    "with-filename", \$with_filename,
) or pod2usage(1);

pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

my $date = "";     # Current date
my $buffer = "";   # Current text in buffer
my $author = "";   # Current author
my @messages = (); # Commit messages of the same author
my $files = "";    # Files affected by CVS change

my $entry_count = 0;

sub print_log {
    exit 0 if $entry_count++ == $entries_limit;

#    print "<li>" . $author . " - " . isodate2any($date, '%Y/%m/%d') . "\n";
 #   print "\t<ul>\n";
    foreach (@messages) {
	print "\t\t<li>" .  $_->{files} . ' ' . $_->{text} . "</li>\n";
    }
 #   print "\t\t</ul>\n";
  #  print "\t</li>\n";
    @messages = ();
}

my $parser = new XML::Parser(
    Handlers => {
        Start => \&handle_StartTag,
        End => \&handle_EndTag,
        Char => \&handle_Text,
    },
);

if ($infile) {
    eval { $parser->parsefile($infile) } or pod2usage("$0: $@");
}
else {
    $parser->parse(\*STDIN);
}

sub handle_StartTag {
    $buffer = "";
}

sub handle_EndTag {
    my (undef, $tag) = @_;

    if ($tag eq "date") {
        print_log() if ($buffer ne $date and @messages and $author and $date);
        $date = $buffer;
    }
    elsif ($tag eq "author") {
        print_log() if ($buffer ne $author and @messages and $author and $date);
        $author = $buffer;
    }
    elsif ($tag eq "msg") {
	my %message = ();
        if ($with_filename) {
            $files =~ s/, $/ /;
	    $message{files} = $files;
            $files = "";
        }
	$message{text} = $buffer;
        unshift @messages, \%message;
    }
    elsif ($tag eq "name" and $with_filename) {
        $files .= $buffer . ", ";
    }
}

sub handle_Text {
    my ($expat, $text) = @_;

    # Encode "special" entities
    $text =~ s/\&/\&amp;/g;
    $text =~ s/</\&lt;/g;
    $text =~ s/>/\&gt;/g;
    #$text =~ s/\"/\&quot;/g;
    #$text =~ s/\'/\&apos;/g;

    # Add current text to the buffer
    $buffer .= $text;
}

__END__

=head1 NAME

cl2html.pl - convert the XML output of cvs2cl.pl to (X)HTML

=head1 SYNOPSIS

cl2html.pl  [--help|--man]  [--with-filename]  [--infile xml_file]

    Options:
        --infile          Parse XML from a file
        --with-filename   Prepend filenames to commit messages
        --help            Show brief help message
        --man             Full documentation

=head1 DESCRIPTION

B<cl2html.pl> converts the XML outputted by cvs2cl.pl's C<--xml> option to
HTML or XHTML code.

=head1 OPTIONS

=over

=item B<--infile xml_file>

Specify which XML file to parse. This file must be the output of cvs2cl.pl's
C<--xml> option. By default, B<cl2html.pl> reads XML code from standard input.

=item B<--with-filename>

This option prepends filenames to each commit message.

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Print the manual page and exits.

=back

=head1 AUTHOR

Copyright (C) 2003 Anderson Lizardo <andersonlizardo@yahoo.com.br>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

=cut

