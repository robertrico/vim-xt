/*
 * cmpf.c - compare two files byte for byte, for the DOS smoke test.
 *
 * Usage: CMPF file1 file2
 * Prints the first difference.  ERRORLEVEL 0 = same, 1 = differ, 2 = error.
 * Plain K&R-compatible C so Turbo C 2.01 can build it too.
 */
#include <stdio.h>

int
main(argc, argv)
    int		argc;
    char	**argv;
{
    FILE	*a, *b;
    int		ca, cb;
    long	off = 0;

    if (argc != 3)
    {
	printf("usage: CMPF file1 file2\n");
	return 2;
    }
    a = fopen(argv[1], "rb");
    b = fopen(argv[2], "rb");
    if (a == NULL || b == NULL)
    {
	printf("CMPF: cannot open %s\n", a == NULL ? argv[1] : argv[2]);
	return 2;
    }
    for (;;)
    {
	ca = getc(a);
	cb = getc(b);
	if (ca != cb)
	{
	    printf("CMPF: %s and %s differ at byte %ld\n",
						    argv[1], argv[2], off);
	    return 1;
	}
	if (ca == EOF)
	    break;
	++off;
    }
    printf("CMPF: %s and %s are the same (%ld bytes)\n",
						    argv[1], argv[2], off);
    return 0;
}
