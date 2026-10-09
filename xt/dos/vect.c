/*
 * vect.c - print the interrupt vector table, one vector per line.
 * Plain C, builds with Turbo C 2.01 too.
 */
#include <stdio.h>
#include <dos.h>

int
main()
{
    unsigned far	*v = (unsigned far *)MK_FP(0, 0);
    int			i;

    for (i = 0; i < 256; ++i)
	printf("%02X %04X:%04X\n", i, v[i * 2 + 1], v[i * 2]);
    return 0;
}
