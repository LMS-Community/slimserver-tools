
#define GRAPHICS_FRAMEBUF_SCRATCH ( 0 * 280 * 2 )
#define GRAPHICS_FRAMEBUF_LIVE    ( 1 * 280 * 2 )
#define GRAPHICS_FRAMEBUF_MASK    ( 2 * 280 * 2 )
#define GRAPHICS_FRAMEBUF_OVERLAY ( 3 * 280 * 2 )

void slimproto_send_graphic(short offset, short length, short *buf);

int slimproto_init(char *client_ip_address);

