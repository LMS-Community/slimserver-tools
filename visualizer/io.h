
#define MAX_AUDIO_CHUNK 2048

struct audio_chunk {
	struct audio_chunk *next, *prev;

	char buf[MAX_AUDIO_CHUNK];
	int length;
};

struct stream {
	struct audio_chunk *head, *tail;

	unsigned long long bytes_in, bytes_out;
};


struct stream *io_stream_alloc(void);
void io_enqueue_chunk(struct stream *s, struct audio_chunk *chunk);
struct audio_chunk *io_dequeue_chunk(struct stream *s);
struct audio_chunk *io_read_chunk_from_file(int in_fd);
int io_pass_through_and_enqueue(int in_fd, int out_fd, struct stream *s);

