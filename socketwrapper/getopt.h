
#ifndef UNIX     /* avoid conflict with stdlib.h */
int getopt(int argc, char **argv, char *opts);
extern char *optarg;
extern int optind;
#endif
