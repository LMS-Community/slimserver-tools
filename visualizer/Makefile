CC = gcc
CFLAGS = -g -O
LIBS = -L./ -lm
AR=ar

default: io.o slimproto.o visualize.o main.o
	$(CC) $(CFLAGS) io.o slimproto.o visualize.o main.o -o vis $(LIBS)
