#!/usr/bin/perl -w
#

use strict;
use IO::File;
use IO::Seekable qw(SEEK_SET);

my $MINFRAMELEN = 96;    # 144 * 32000 kbps / 48000 kHz + 0 padding
my $MAXDISTANCE = 4048;  # 144 * 320000 kbps / 32000 kHz + 1 padding + fudge factor for garbage data

my @BITRATE_TABLE=(0,32,40,48,56,64,80,96,112,128,160,192,224,256,320,-1);
my @FREQ_TABLE=(44100,48000,32000,-1);

# seekNextFrame:
# starts seeking from $startoffset (bytes relative to beginning of file) until 
# it finds the next valid frame header. Returns the offset of the first and last
# bytes of the frame if any is found, otherwise (0,0).
#
# when scanning forward ($direction=1), simply detects the next frame header.
#
# when scanning backwards ($direction=-1), returns the next frame header whose
# frame length is within the distance scanned (so that when scanning backwards 
# from EOF, it skips any truncated frame at the end of file.
#
sub seekNextFrame {
	my ($fh, $startoffset, $direction) =@_;
	defined($fh) || die;
	defined($startoffset) || die;
	defined($direction) || die;

	my $foundsync=0;
	my ($seekto, $buf, $len, $h, $pos, $start, $end);
	my ($h_no_crc, $h_bitrate_code, $h_freq_code, $h_has_padding, $h_private_bit, $h_channelmode, 
		$h_modeext, $h_copyright, $h_original, $h_emph);
	my ($bitrate, $freq, $calculatedlength, $numgarbagebytes);
	my ($found_at_offset);

	$seekto = ($direction == 1) ? $startoffset : $startoffset-$MAXDISTANCE;
	print("seeking to: $seekto\n");
	seek($fh, $seekto, SEEK_SET);
	read $fh, $buf, $MAXDISTANCE, 0;

	$len = length($buf);
	if ($len<4) {
		print "got less than 4 bytes\n";
		return (0,0) 
	}

	if ($direction==1) {
		$start = 0;
		$end = $len-4;
	} else {
		#assert($direction==-1);
		$start = $len-$MINFRAMELEN;
		$end=-1;
	}

	printf("len = $len, start = $start, end = $end\n");

	for ($pos = $start; $pos!=$end; $pos+=$direction) {
		#printf "looking at $pos\n";
		$h = unpack('N',substr($buf, $pos, 4));
		(($h & 0xfffe0000) == 0xfffa0000) || next;  # match sync pattern (11 bits + '1101' for mp3)
		(($h & 0x0000f000) == 0x0000f000) && next;  # skip invalid bitrate 
		(($h & 0x00000c00) == 0x00000c00) && next;  # skip invalid freq

		$found_at_offset = $startoffset + (($direction==1) ? $pos : ($pos-$len));

		printf "sync at %d : %08x\n", $found_at_offset, $h;
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

		# when scanning backwards, skip any truncated frame at the end of the buffer
		if ($direction == -1) {
			$numgarbagebytes = $len-$pos+1 - $calculatedlength;
			printf "%d byte(s) of crap at the end.\n", $numgarbagebytes;

			if ($numgarbagebytes<0) {
				print "calculated length > bytes remaining. Either this wasn't a real frame header,\nor the frame was truncated. Searching further...\n\n";
				$foundsync=0;
				next;
			}
		}

		return($found_at_offset, $found_at_offset + $calculatedlength - 1);
	}

	if (!$foundsync) {
		printf("Couldn't find any frame header\n");
		return(0,0);
	}
}


my $filename = pop(@ARGV) || '';
my $fh = new IO::File;
print("opening: $filename\n");
$fh->open($filename) || die "can't open: $filename";

my $eofpos = (-s$filename)-1;

my ($startoffset, $endoffset);

printf("seeking backwards from EOF ($eofpos)\n");
($startoffset, $endoffset) = &seekNextFrame($fh, $eofpos, -1);
printf("returned $startoffset, $endoffset\n");

printf("seeking forward from beginning of file (0)\n");
($startoffset, $endoffset) = &seekNextFrame($fh, 0, 1);
printf("returned $startoffset, $endoffset\n");
