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

char frame[2048];

int sockfd;
struct sockaddr_in *client_addr;
struct sockaddr_in *recv_addr;

/* sends the packet that tells the client to start running it's main program */
void sendframe(void) {
	int i;

	((short *)(frame))[0]=560+4;
	frame[2]='g';
 	frame[3]='r';
	frame[4]='a';
	frame[5]='f';

	for (i=0; i<560; i++) 
		frame[6+i]=i;	

	if (sendto(sockfd,&frame,(560+4+2),0,(struct sockaddr *)client_addr, sizeof(struct sockaddr))==-1) {    
		perror("sendto");
		exit(1);
	}
}


struct sockaddr_in *setupaddr(char *address, int port) {
  struct in_addr ip;
  struct sockaddr_in *addr;

  addr=malloc(sizeof(struct sockaddr));

  if (!address || !(inet_aton(address, &ip))) {  
    printf("OOPS! Bad IP address: %s\n", address);
    exit(1);
  }

  addr->sin_family = AF_INET;
  addr->sin_port = htons(port);
  addr->sin_addr = ip;
  return addr;
}
        
int main(int argv, char *argc[]) {

  if ((sockfd = socket(AF_INET, SOCK_DGRAM, 0)) == -1) {
    perror("socket");
    exit(1);
  }

  client_addr = setupaddr(argc[1], SLIMPROTO_PORT);

  sendframe();
}

















