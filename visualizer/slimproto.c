#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <netdb.h>
#include <sys/socket.h>

#define  SLIMPROTO_PORT    3483


int sockfd;
struct sockaddr_in *client_addr;
struct sockaddr_in *recv_addr;

void slimproto_send_graphic(short offset, short length, short *buf) {
	int p,i;

	short frame[2048];

	fprintf(stderr, "graphic, offs = %d, len = %d\n", offset, length);

	p=0;
	frame[p++] = htons(length+4+2);	// 4 bytes for "grfd", 2 for offset
	frame[p++] = htons(('g' << 8) | 'r');
	frame[p++] = htons(('f' << 8) | 'd');

// parameter for grfd command
	frame[p++] = htons(offset);

	for (i=0; i<length; i++) 
		frame[p++]=buf[i];

	if (sendto(sockfd,frame,p,0,(struct sockaddr *)client_addr, sizeof(struct sockaddr))==-1) {    
		fprintf(stderr, "sendto");
		exit(1);
	}
}


struct sockaddr_in *setupaddr(char *address, int port) {
	struct in_addr ip;
	struct sockaddr_in *addr;

	addr=malloc(sizeof(struct sockaddr));

	if (!address || !(inet_aton(address, &ip))) {  
		fprintf(stderr, "OOPS! Bad IP address: %s\n", address);
		exit(1);
	}

	addr->sin_family = AF_INET;
	addr->sin_port = htons(port);
	addr->sin_addr = ip;
	return addr;
}
        
int slimproto_init(char *client_ip_address) {

	fprintf(stderr, "slimproto_init: %s\n", client_ip_address);

	if ((sockfd = socket(AF_INET, SOCK_DGRAM, 0)) == -1) {
		perror("socket");
		return(0);
		}

	client_addr = setupaddr(client_ip_address, SLIMPROTO_PORT);

}

















