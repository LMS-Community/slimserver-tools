#!/usr/bin/perl -w
#

use strict;
use IO::Seekable qw(SEEK_END);

my $MINFRAMELEN = 96;    # 144 * 32000 kbps / 48000 kHz + 0 padding
my $MAXFRAMELEN = 4048;  # 144 * 320000 kbps / 32000 kHz + 1 padding + fudge factor for garbage data

my @BITRATE_TABLE=(0,32,40,48,56,64,80,96,112,128,160,192,224,256,320,-1);
my @FREQ_TABLE=(44100,48000,32000,-1);

my $foundsync=0;
my ($buf, $len, $h, $pos);
my ($h_no_crc, $h_bitrate_code, $h_freq_code, $h_has_padding, $h_private_bit, $h_channelmode, 
	$h_modeext, $h_copyright, $h_original, $h_emph);
my ($bitrate, $freq, $calculatedlength, $numgarbagebytes);

my $filename = pop(@ARGV) || '';
print("opening: $filename\n");
open MP3, $filename || die "can't open: $filename";
seek MP3, -$MAXFRAMELEN, SEEK_END;
read MP3, $buf, $MAXFRAMELEN, 0;

$len = length($buf);

# scan backwards from the end of the buffer, starting and end-96 (shortest possible frame)
# skips anything that's not a frame header as quickly as possible
for ($pos = 96; $pos<=$MAXFRAMELEN; $pos++) {
	$h = unpack('N',substr($buf, -$pos, 4));
	(($h & 0xfffe0000) == 0xfffa0000) || next;  # match sync pattern (11 bits + '1101' for mp3)
	(($h & 0x0000f000) == 0x0000f000) && next;  # skip invalid bitrate 
	(($h & 0x00000c00) == 0x00000c00) && next;  # skip invalid freq
	printf "sync at -%d : %08x\n", $pos, $h;
	$foundsync=1;
	
	$h_no_crc =       ($h & 0x00010000) >> 16;	# 0 == has CRC, 1 == no CRC
	$h_bitrate_code = ($h & 0x0000f000) >> 12;
	$h_freq_code =    ($h & 0x00000c00) >> 10;
	$h_has_padding =  ($h & 0x00000200) >> 9;
	$h_private_bit =  ($h & 0x00000100) >> 8;
	$h_channelmode =  ($h & 0x000000c0) >> 6;
	$h_modeext =      ($h & 0x00000030) >> 4;
	$h_copyright =    ($h & 0x00000008) >> 3;
	$h_original =     ($h & 0x00000004) >> 2;
	$h_emph =         ($h & 0x00000003) >> 0;

	printf "no_crc: %d, bitrate_code: %d, freq_code: %d, has_padding: %d, private_bit: %d\n".
		"channelmode: %d, modeext: %d, copyright: %d, original: %d, emph: %d\n",
		$h_no_crc, $h_bitrate_code, $h_freq_code, $h_has_padding, $h_private_bit, 
		$h_channelmode, $h_modeext, $h_copyright, $h_original, $h_emph;

	$bitrate = $BITRATE_TABLE[$h_bitrate_code];
	$freq = $FREQ_TABLE[$h_freq_code];
	$calculatedlength = int(144 * $bitrate * 1000 / $freq) + $h_has_padding;
	print "Bit rate: $bitrate, Sample rate: $freq, Calculated length including header: $calculatedlength\n";

	$numgarbagebytes = $pos - $calculatedlength;

	if ($numgarbagebytes<0) {
		print "calculated length < offset. Either this wasn't a real frame header,\nor the frame was truncated. Searching further...\n\n";
		$foundsync=0;
		next;
	}

	printf "%d byte(s) of crap at the end.\n", $numgarbagebytes;

	if ($numgarbagebytes>1) {
		print "MORE THAN 1 BYTE OF GARBAGE.\n";
	}
	last;
}

if (!$foundsync) {
	printf("Couldn't find any frame header within last $MAXFRAMELEN bytes.\n");
}

printf("\n");
