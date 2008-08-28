#!/usr/bin/perl -w

use strict;
use IO::Socket;
use FileHandle;
use Data::Dumper;
# Send main volume data via the Squeezecenter CLI to Boom DSP.
sub usage
{
    print ("usage: perl set_volume.pl <playername> <volume_db>\n");
    print ("       where playername is your boom playername, volume is the volume between 10 and -100 in dB.\n");
    exit(-1);
}

if (@ARGV != 2) {usage()};
my $playername = $ARGV[0];
my $volume_db  = $ARGV[1];

sub asc2i2c
{
    my ($asc_data) = @_;
    my $len = length($asc_data);
    my $result = '';
    for (my $i = 0; $i < $len; $i+=2) {
	$result = $result . "%" . substr($asc_data, $i, 2);
    }
    return $result;
}

# Convert volume in db to linear
if ($volume_db > 10) {
    print "You really, really don't want the volume to be this big.  Try something smaller";
    exit(0);
}
my $volume = 10.0**($volume_db/20.0);
if ($volume_db eq 'mute') {
    $volume = 0;
}
my $volume_int = int(($volume * 0x01000000)+0.5);

my $stereoxl_i2c_address = 47;
my $command = sprintf("%02x%08x", $stereoxl_i2c_address, $volume_int);
my $sock = new IO::Socket::INET(
			  PeerAddr => 'localhost',
			  PeerPort => '9090',
			  Proto    => 'tcp',
			  );

die "Couldn't open socket $!\n" unless $sock;

print "Setting DAC volume to $volume_db dB ($volume)\n";
print $sock "$playername boomdac " . asc2i2c($command) . "\n";
close($sock);
