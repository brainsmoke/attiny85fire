
#include <sys/ioctl.h>

#include <linux/spi/spidev.h>

#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <sys/time.h>
#include <time.h>

const uint8_t color_tab[192] = {

/*

for i in range(64):
    r = min(255,i*12)
    g = min(255,((i/64.)**1.5)*1024.)
    b = min(255,i*i/16)
    r = int( ( (r/255.)**2.2 ) *255 )
    g = int( ( (g/255.)**2.2 ) *255 )
    b = int( ( (b/255.)**2.2 ) *255 )
    print(f"    {g:4d},{r:4d},{b:4d},", end='')
    if i % 4 == 3:
        print()
*/

       0,   0,   0,       0,   0,   0,       0,   1,   0,       0,   3,   0,
       0,   6,   0,       1,  10,   0,       2,  15,   0,       3,  22,   0,
       5,  29,   0,       8,  38,   0,      11,  48,   0,      16,  59,   0,
      21,  72,   0,      28,  86,   0,      36, 101,   0,      45, 118,   0,
      55, 136,   0,      68, 156,   0,      82, 176,   0,      98, 199,   1,
     116, 223,   1,     137, 248,   1,     160, 255,   2,     185, 255,   2,
     213, 255,   3,     244, 255,   4,     255, 255,   4,     255, 255,   5,
     255, 255,   6,     255, 255,   7,     255, 255,   9,     255, 255,  10,
     255, 255,  12,     255, 255,  13,     255, 255,  15,     255, 255,  18,
     255, 255,  20,     255, 255,  23,     255, 255,  25,     255, 255,  29,
     255, 255,  32,     255, 255,  36,     255, 255,  40,     255, 255,  44,
     255, 255,  49,     255, 255,  54,     255, 255,  60,     255, 255,  66,
     255, 255,  72,     255, 255,  79,     255, 255,  86,     255, 255,  94,
     255, 255, 103,     255, 255, 112,     255, 255, 121,     255, 255, 132,
     255, 255, 142,     255, 255, 154,     255, 255, 166,     255, 255, 179,
     255, 255, 193,     255, 255, 208,     255, 255, 223,     255, 255, 239,

};

const uint8_t ca_map[512] = {

/*
for i,v in enumerate( int(((i/64)**1.25)/3.7*64.) for i in range(512) ):
    print(f"{v:4d},", end='')
    if i % 16 == 15:
        print()
 */
   0,   0,   0,   0,   0,   0,   0,   1,   1,   1,   1,   1,   2,   2,   2,   2,
   3,   3,   3,   3,   4,   4,   4,   4,   5,   5,   5,   5,   6,   6,   6,   6,
   7,   7,   7,   8,   8,   8,   9,   9,   9,   9,  10,  10,  10,  11,  11,  11,
  12,  12,  12,  13,  13,  13,  13,  14,  14,  14,  15,  15,  15,  16,  16,  16,
  17,  17,  17,  18,  18,  19,  19,  19,  20,  20,  20,  21,  21,  21,  22,  22,
  22,  23,  23,  23,  24,  24,  25,  25,  25,  26,  26,  26,  27,  27,  27,  28,
  28,  29,  29,  29,  30,  30,  30,  31,  31,  32,  32,  32,  33,  33,  34,  34,
  34,  35,  35,  35,  36,  36,  37,  37,  37,  38,  38,  39,  39,  39,  40,  40,
  41,  41,  41,  42,  42,  43,  43,  43,  44,  44,  45,  45,  46,  46,  46,  47,
  47,  48,  48,  48,  49,  49,  50,  50,  50,  51,  51,  52,  52,  53,  53,  53,
  54,  54,  55,  55,  56,  56,  56,  57,  57,  58,  58,  59,  59,  59,  60,  60,
  61,  61,  62,  62,  63,  63,  63,  64,  64,  65,  65,  66,  66,  66,  67,  67,
  68,  68,  69,  69,  70,  70,  70,  71,  71,  72,  72,  73,  73,  74,  74,  75,
  75,  75,  76,  76,  77,  77,  78,  78,  79,  79,  80,  80,  80,  81,  81,  82,
  82,  83,  83,  84,  84,  85,  85,  86,  86,  86,  87,  87,  88,  88,  89,  89,
  90,  90,  91,  91,  92,  92,  93,  93,  94,  94,  94,  95,  95,  96,  96,  97,
  97,  98,  98,  99,  99, 100, 100, 101, 101, 102, 102, 103, 103, 104, 104, 105,
 105, 106, 106, 107, 107, 107, 108, 108, 109, 109, 110, 110, 111, 111, 112, 112,
 113, 113, 114, 114, 115, 115, 116, 116, 117, 117, 118, 118, 119, 119, 120, 120,
 121, 121, 122, 122, 123, 123, 124, 124, 125, 125, 126, 126, 127, 127, 128, 128,
 129, 129, 130, 130, 131, 131, 132, 132, 133, 133, 134, 134, 135, 135, 136, 136,
 137, 137, 138, 138, 139, 140, 140, 141, 141, 142, 142, 143, 143, 144, 144, 145,
 145, 146, 146, 147, 147, 148, 148, 149, 149, 150, 150, 151, 151, 152, 152, 153,
 154, 154, 155, 155, 156, 156, 157, 157, 158, 158, 159, 159, 160, 160, 161, 161,
 162, 162, 163, 164, 164, 165, 165, 166, 166, 167, 167, 168, 168, 169, 169, 170,
 170, 171, 172, 172, 173, 173, 174, 174, 175, 175, 176, 176, 177, 177, 178, 178,
 179, 180, 180, 181, 181, 182, 182, 183, 183, 184, 184, 185, 186, 186, 187, 187,
 188, 188, 189, 189, 190, 190, 191, 192, 192, 193, 193, 194, 194, 195, 195, 196,
 196, 197, 198, 198, 199, 199, 200, 200, 201, 201, 202, 203, 203, 204, 204, 205,
 205, 206, 206, 207, 207, 208, 209, 209, 210, 210, 211, 211, 212, 213, 213, 214,
 214, 215, 215, 216, 216, 217, 218, 218, 219, 219, 220, 220, 221, 221, 222, 223,
 223, 224, 224, 225, 225, 226, 227, 227, 228, 228, 229, 229, 230, 231, 231, 232,

};

int spi_transfer(int fd, char *in, const char *out, size_t len)
{
	struct spi_ioc_transfer transfer =
	{
		.tx_buf        = (unsigned long)out,
		.rx_buf        = (unsigned long)in,
		.len           = len,
		.delay_usecs   = 0,
	};

	return ioctl(fd, SPI_IOC_MESSAGE(1), &transfer);
}

int spi_open(const char *devname, int mode, int speed, int bits_per_word)
{
	int fd = open(devname, O_RDWR);

	if (fd < 0)
		return fd;
	
	if ( (ioctl(fd, SPI_IOC_WR_MODE, &mode) == 0) &&
	     (ioctl(fd, SPI_IOC_WR_BITS_PER_WORD, &bits_per_word) == 0) &&
	     (ioctl(fd, SPI_IOC_WR_MAX_SPEED_HZ, &speed) == 0) )
		return fd;

	close(fd);
	return -1;
}


/* https://www.avrfreaks.net/forum/tiny-fast-prng */
uint8_t prng(void)
{
	static uint8_t s=0xaa, a=0;
	s^=s<<3;
	s^=s>>5;
	s^=a++>>2;
	return s;
}

void do_ca(uint8_t cells[], int w, int h)
{
	int x, y, sum;

	for (y=0; y<h; y++)
	{
		sum = cells[y*w+w] + cells[y*w+w+1];
		cells[y*w] = ca_map[sum<511?sum:511];
		for (x=1; x<w-1; x++)
		{
			sum = cells[y*w+w+x-1] + cells[y*w+w+x] + cells[y*w+w+x+1];
			cells[y*w+x] = ca_map[sum<511?sum:511];
		}
		sum = cells[y*w+w+w-2] + cells[y*w+w+w-1];
		cells[y*w+w-1] = ca_map[sum<511?sum:511];
	}

	unsigned long noise;//rand();
	for (x=0; x<w; x++)
	{
		if ( (x&7) == 0)
			noise = prng();
		cells[h*w+x] = (noise&1) ? 57 : 0;
		noise >>= 1;
	}
}

void fire(int fd, int width, int height, int transform_map[])
{
	char send_buf[height*width*3]; memset(send_buf, 0, sizeof(send_buf));
	int w = width*2, h = height*2; int s=w*(h+1);
	uint8_t cells[s]; memset(cells, 0, sizeof(cells));

	int j, y, i;
	struct timeval tv; gettimeofday(&tv, NULL);

	int wait, usec=tv.tv_usec, fps = 0;

	for(;;)
	{
		do_ca(cells, w, h);

		for (i=y=0; y<height; y++)
			for (j=0; j<w; j+=2,i++)
			{
				int ix = ( cells[i*4-j] + cells[i*4-j+1] +
				           cells[i*4+w-j] + cells[i*4+w-j+1] ) >> 2;

				if (ix > 63)
					ix=0;

				ix += ix << 1;
				int map = transform_map[i];
				map += map << 1;

				send_buf[map++] = color_tab[ix++];
				send_buf[map++] = color_tab[ix++];
				send_buf[map  ] = color_tab[ix  ];
			}

		spi_transfer(fd, NULL, send_buf, width*height*3);

		usec += 20000; usec %= 1000000;
		gettimeofday(&tv, NULL);
		wait = 1000000 + usec - tv.tv_usec; wait %= 1000000;
		if (wait < 20000)
			usleep(wait);
	}
}

void init_transform_map(int width, int height, int map[])
{
	int x, y;
	for (y=0; y<height; y++)
		for (x=0; x<width; x++)
			map[y*width+x] = (x&1) ? height*x + y : height*(x+1)-1 - y;
}

int main(int argc, char *argv[])
{
	if (argc < 2)
	{
		fprintf(stderr, "Usage: %s <spi-device>\n", argv[0]);
		exit(EXIT_FAILURE);
	}

	int fd = spi_open(argv[1], 0, 2000000, 8);

	int transform_map[12*10]; init_transform_map(12, 10, transform_map);

	fire(fd, 12, 10, transform_map);
}
