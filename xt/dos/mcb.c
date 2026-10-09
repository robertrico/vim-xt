/*
 * mcb.c - list the DOS memory control block chain: segment, owner PSP,
 * size and owner name.  Shows what a program (e.g. Vim during :!) holds.
 * Plain C, builds with Turbo C 2.01 too.
 */
#include <stdio.h>
#include <dos.h>

int
main()
{
    union REGS		r;
    struct SREGS	s;
    unsigned		seg, owner, size, i;
    unsigned char far	*m;
    char		name[9];

    r.h.ah = 0x52;		/* list of lists, first MCB at ES:BX-2 */
    intdosx(&r, &r, &s);
    seg = *(unsigned far *)MK_FP(s.es, r.x.bx - 2);
    printf("MCB  seg   owner  bytes   name\n");
    for (;;)
    {
	m = (unsigned char far *)MK_FP(seg, 0);
	owner = *(unsigned far *)(m + 1);
	size = *(unsigned far *)(m + 3);
	name[0] = 0;
	if (owner > 8)		/* owner's MCB holds its name (DOS 4+) */
	{
	    unsigned char far *o = (unsigned char far *)MK_FP(owner - 1, 0);
	    for (i = 0; i < 8 && o[8 + i] >= ' '; ++i)
		name[i] = o[8 + i];
	    name[i] = 0;
	}
	printf("%c  %04X  %04X  %6lu  %s%s\n", m[0], seg + 1, owner,
		(unsigned long)size * 16, owner == 0 ? "(free)" : "",
		name);
	if (m[0] != 'M')
	    break;
	seg += size + 1;
    }
    return 0;
}
