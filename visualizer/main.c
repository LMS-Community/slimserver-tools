#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <netdb.h>
#include <sys/socket.h>
#include <sys/uio.h>
#include <unistd.h>
#include <fcntl.h>

#include "slimproto.h"
#include "io.h"
#include "visualize.h"

int main (int argv, char *argc[]) {

	char *client_ip_address = argc[1];
	char *infile_name = argc[2];
	int in_fd;
	struct audio_chunk *chunk;

	struct stream *s;

	struct timeval tv;

	tv.tv_sec = 0;
	tv.tv_usec = 1000;

	slimproto_init(client_ip_address);
	
	in_fd = open(infile_name, O_RDONLY);

	if (!in_fd) {
		fprintf(stderr, "couldn't open: %s", infile_name);
		exit(1);
	}

	s = io_stream_alloc();

	

	while (io_pass_through_and_enqueue(in_fd, STDOUT_FILENO, s)) {
		fprintf(stderr, "in: %lld, out: %lld\n", s->bytes_in, s->bytes_out);
		
		if ( (s->bytes_in - s->bytes_out) >= 224000 ) {
			chunk = io_dequeue_chunk(s);
			visualize(chunk);
			free(chunk);
		}

		select(0, NULL, NULL, NULL, &tv);
	}

}
