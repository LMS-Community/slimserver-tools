#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include <fcntl.h>

#include "slimproto.h"
#include "io.h"
#include "visualize.h"

#define HISTORY_WIDTH  128

void visualize (struct audio_chunk *chunk) {

	int i, j, chan;
	int numsamples;
	float sample, rms[2];
	unsigned short graphic[280];

	static unsigned short history[HISTORY_WIDTH];

	signed short *buf;

	unsigned short n, m;
	signed short sample_signed16;

	if (!chunk) {
		fprintf(stderr, "visualize: !chunk\n");
		return;
	}

	if (!chunk->length) {
		fprintf(stderr, "visualize: !chunk->length\n");
		return;
	}

	// calculate RMS power of each channel

	numsamples = chunk->length / 2 / 2;

	buf = (signed short *)(chunk->buf);

	for (chan=0; chan<2; chan++) {

		rms[chan]=0;

		for (i=0; i<numsamples; i++) {
		
			sample_signed16 = ntohs(buf[2*i+chan]);
			if (sample_signed16 < 0)
				sample_signed16 = 0-sample_signed16;

			sample = sample_signed16;
			sample /= (1<<14);

			rms[chan] += sample * sample / numsamples;
		}

		rms[chan] = sqrt(rms[chan]);
	}

//	fprintf(stderr, "rms: %f, %f\n", rms[0], rms[1]);

	// draw graphic

	for (i=0; i<280; i++) {
		graphic[i] = 0x0000;

//		if (rms[0] * 280 >= i)
///			graphic[i] |= htons(0x8000);
//		
//		if (rms[1] * 280 >= i)
//			graphic[i] |= htons(0x0001);
	}

	for (i=HISTORY_WIDTH-1; i>0; i--)
		history[i] = history[i-1];
	
	n = 16 * (rms[0] + rms[1]) / 2;

	m=1;
	while (n) {
		m = (m << 1) | 1;
		n --;
	}

	history[0] = htons(m);

	for (i=0; i<HISTORY_WIDTH; i++) {
		graphic[280-HISTORY_WIDTH+i] = history[HISTORY_WIDTH-i-1];
	}

	slimproto_send_graphic(GRAPHICS_FRAMEBUF_OVERLAY, 560, graphic);
}
