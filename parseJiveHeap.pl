#!/usr/bin/perl

# parseJiveHeap.pl
#
# walks the xml tree of a jive.heap memory dump and attempts to 
# breakdown the components of userdata objects (surface, icon, window, etc.) currently
# in memory
#
# requires XML::Twig, which also requires XML::Parser and expat. XML::* modules available from CPAN
# expat can be found on sourceforge
#
# first version: bklaas 03.08

use strict;
use XML::Twig;
use Data::Dump qw( dump );

my %userdata;
my %userdataIds;
my %rootTableId;

my $file = $ARGV[0] || 'heap.xml';
die "no such file readable" unless -r $file;

my $t = XML::Twig->new(
	twig_handlers => {
		userdata => sub {
				my ( $t, $g ) = @_;
				
				#print dump($g);
				my $userdata = {
					id           => $g->{'att'}->{'id'},
					cycle		=> $g->{'att'}->{'cycle'},
					metatable	=> $g->first_child('metatable'),
				};
				if ($userdata->{'metatable'}->{'att'}->{'cycle'} ne 'true') {
					my $metatableId = $userdata->{'metatable'}->{'att'}->{'id'};
					$rootTableId{$metatableId} = $userdata->{id};
				}
				$userdataIds{$userdata->{id}}++;
				if ($g->first_child =~ /HASH/) {
					$userdata->{metatable}	= $g->first_child->{'att'}->{'id'};
					if ($userdata->{cycle} ne 'true') {
						#print "$userdata->{id}\t$userdata->{metatable}\n";
						$userdata{$userdata->{metatable}}++;
					}
				}
				$t->purge;
			},
		}
	);

$t->parsefile($file);

for my $key ( sort { $userdata{$b} <=> $userdata{$a} }  keys %userdata ) {
	print "$key\t$userdata{$key}\t$rootTableId{$key}\n";
}
