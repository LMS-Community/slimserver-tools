
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <netdb.h>
#include <sys/socket.h>

#include "io.h"


struct stream *io_stream_alloc(void) {

	struct stream *s = malloc(sizeof(struct stream));

	s->head = NULL;
	s->tail = NULL;
	s->bytes_in = 0;
	s->bytes_out = 0;
}


void io_enqueue_chunk(struct stream *s, struct audio_chunk *chunk) {
	
	struct audio_chunk *temp;

	s->bytes_in += chunk->length;

	temp = s->head;
	s->head = chunk;
	chunk->next = temp;
	chunk->prev = NULL;

	if (!s->tail)
		s->tail = chunk;

}

struct audio_chunk *io_dequeue_chunk(struct stream *s) {

	struct audio_chunk *chunk;

	if (!s->tail)
		return NULL;

	chunk = s->tail;

	if (!chunk->prev) {
		s->head=NULL;
		s->tail=NULL;
	} else {
		chunk->prev->next = NULL;
		s->tail=chunk->prev;
	}

	s->bytes_out += chunk->length;	
	return chunk;
}


struct audio_chunk *io_read_chunk_from_file(int in_fd) {

	struct audio_chunk *chunk;

	chunk = malloc(sizeof(struct audio_chunk));

	chunk->length = read (in_fd, chunk->buf, MAX_AUDIO_CHUNK);

	if (!chunk->length) {
		free(chunk);
		chunk=NULL;
	}
	
	return chunk;
}


// copy a chunk from in to out while enqueuing the data

int io_pass_through_and_enqueue (int in_fd, int out_fd,  struct stream *s) {

	struct audio_chunk *chunk;
	int bytes_written;

	chunk = io_read_chunk_from_file(in_fd);

	if(!chunk)
		return 0;

	io_enqueue_chunk(s, chunk);

	bytes_written = write(out_fd, chunk->buf, chunk->length);

	if (bytes_written != chunk->length) 
		return 0;	// TODO handle write errors, partial write

	return 1;
}
