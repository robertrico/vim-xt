/*
 * freemem.c - print the largest block DOS can allocate, i.e. how big a
 * program could be loaded now.  Used to measure what Vim leaves for :!.
 * Plain C, builds with Turbo C 2.01 too.
 */
#include <stdio.h>
#include <dos.h>

int
main()
{
    union REGS	r;

    r.h.ah = 0x48;		/* allocate memory: ask for 1 MB */
    r.x.bx = 0xffff;
    intdos(&r, &r);		/* fails, BX = largest free block */
    printf("FREEMEM: largest free block %lu bytes (%u KB)\n",
	    (unsigned long)r.x.bx * 16, (unsigned)(r.x.bx / 64));
    return 0;
}
