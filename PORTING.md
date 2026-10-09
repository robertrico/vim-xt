# Porting notes: Vim 5.8 to Open Watcom, 16-bit DOS, IBM PC/XT

Every change against upstream Vim 5.8 (tag `vim-5.8.009` on branch
`upstream`) is listed here with the reason, so the diff stays explainable.

## Baseline

The `upstream` branch is the Vim 5.8 release tarballs plus the official
patches 5.8.001 to 5.8.009 (the last 5.8 patch):

    ftp.nluug.nl/pub/vim/unix/vim-5.8-src.tar.gz
    ftp.nluug.nl/pub/vim/unix/vim-5.8-rt.tar.gz
    ftp.nluug.nl/pub/vim/extra/vim-5.8-extra.tar.gz   (DOS, Win32, ... files)
    ftp.nluug.nl/pub/vim/patches/5.8.001 .. 5.8.009

It is **not** taken from github.com/vim/vim-history.  That repository's
CVS import breaks at commit c3cba927 ("vim-5.7 pl 002 --> vim-6.0d"): every
tag from `vim-5-7-003` through `vim-5-8-009` contains 6.0d ALPHA sources
(fold.c, FEAT_TINY, Make_bc3.mak, Make_tcc.mak) with 5.8 version strings
pasted on, and they don't even agree with themselves (`WIN` in globals.h,
`win_t` in structs.h).  The 5.8 equivalents of the names in that tree:

| 6.0d hybrid      | real 5.8                     |
|------------------|------------------------------|
| FEAT_TINY        | MIN_FEAT (default for MSDOS) |
| Make_bc3.mak     | Makefile.bcc (Borland C++)   |
| Make_tcc.mak     | Makefile.dos (Turbo C)       |

`src/os_msdos.c` in the tarball is identical (apart from CR-LF) to the one
in the PC source archive `pc/vim58src.zip`.

## Build files (new)

* `src/Make_wat.mak` - wmake makefile.  Same code generation choices as
  Makefile.bcc: large model, 8086 instructions only, no floating point,
  MIN_FEAT.  `-j` makes `char` signed like Borland's default.  `-zt=256`
  moves data items over 256 bytes out of DGROUP.  `DEBUG=1` keeps stack
  checking and adds debug info.  Stack is 8K (Borland default was 4K with
  `-N` stack checking; to be measured in phase 2).

## src/os_msdos.h

* `<dir.h>` is Borland only.  Watcom: `<direct.h>` (getcwd, chdir, mkdir,
  rmdir) and `<env.h>` (setenv).

## src/os_msdos.c

All under `#ifdef __WATCOMC__`; the Borland and DJGPP code is unchanged
except where noted.

* **Console output.**  Borland's conio has a "text window" API (`window()`,
  `gotoxy()`, `insline()`, `delline()`, `clreol()`, `clrscr()`,
  `textattr()`, `gettextinfo()`, `textmode()`) that Watcom lacks.  Added a
  small direct-video layer that keeps Borland's semantics, which Vim
  depends on: for "pcterm" Vim sets `T_CCS` (term.c), meaning cursor
  positions are relative to the scroll region, which is how Borland's
  `gotoxy()` inside a `window()` behaves.
  * Characters go straight to video memory, B000 (mode 7, MDA/Hercules)
    or B800, at the BIOS active-page offset.
  * Insert/delete line, scroll and clear screen use BIOS int 10h AH=06/07,
    which blanks the display on a CGA instead of snowing.
  * On an IBM CGA (B800 and no EGA/VGA BIOS), each character store waits
    for horizontal retrace (port 3DAh bit 0) to avoid snow.
  * The hardware cursor is only moved (int 10h AH=02) when Vim waits for a
    key or for a timeout, and when interrupts are restored before exit or
    a shell.  Borland moved it on every character.
* `mch_write()` called `clrscr()`, `clreol()`, `insline()`, `delline()`
  directly; now through `my*()` names like the rest, mapped back to the
  conio calls for Borland and DJGPP.  *(touches the shared code path)*
* **Library differences**, mapped with macros or small helpers:
  `bioskey` -> `_bios_keybrd`; `biostime` -> read 0040:006C with
  interrupts off (int 1Ah AH=0 would clear the midnight flag);
  `coreleft` -> largest DOS block (int 21h AH=48h, BX=FFFF);
  `searchpath` -> `_searchenv`; `getcbrk`/`setcbrk` -> int 21h AX=3300/3301;
  `_chmod` -> `_dos_getfileattr`/`_dos_setfileattr`;
  `findfirst`/`findnext`/`struct ffblk` -> `_dos_findfirst`/`_dos_findnext`/
  `struct find_t`; `FA_ARCH`/`FA_DIREC` -> `_A_ARCH`/`_A_SUBDIR`;
  `<alloc.h>` -> `<malloc.h>`; `_fullpath()` exists in Watcom too.
* `cons_getkey()` reads the zero flag after int 21h AH=06; Watcom's
  16-bit `union REGS` has no flags, so it uses `intr()` with `REGPACK`.
* **Interrupt handlers** rewritten with `__interrupt __far`: int 1Bh
  (ctrl-break), int 24h (critical error, `union INTPACK` to set AL), and
  int 23h replacing Borland's `ctrlbrk()`.  All three vectors are restored
  when Vim exits or runs a shell (Borland's version left int 23h alone).
* `_cdecl` is defined empty for Watcom: Watcom's `qsort()` calls the
  comparator with its default register convention, so a `_cdecl`
  comparator would crash.  The `qsort()` call in `dos_expandpath()` got a
  cast to the standard comparator type.
* `extern int _fmode;` skipped for Watcom, where `_fmode` is a macro.
* `mch_screenmode()`: `textmode()` replaced by int 10h AH=00, plus the 8x8
  font (AX=1112h) for C4350 on EGA/VGA.
* `mch_get_winsize()`: columns from int 10h AH=0Fh, rows from 0040:0084
  on EGA/VGA, else 25.

## Swapping Vim out for :! and :make (new: src/dosswap.asm)

Vim holds about 480K of 640K (code, data, heap), so a program run with `:!`
got about 60K: not enough for MAKE plus TCC.  The Borland build used the
SPAWNO library for this (`-DSPAWNO` in Makefile.bcc).  Our own swapper:

* `src/dosswap.asm` is a 1.5K stub, linked first so it sits right after
  the PSP.  It writes the rest of the main memory block and every other
  DOS block Vim owns (the heap) to a swap file, frees them, runs the
  program with DOS EXEC, then reallocates the blocks at the same
  segments and reads everything back.  First-fit allocation that lands
  in an older free gap is held off with placeholder blocks.  A failure
  before memory is freed returns an error; after that it can't be undone,
  so it prints how to recover from the .swp file and exits.
* `os_msdos.c` `swap_shell()`, called from `mch_call_shell()`, fills in
  the stub's parameters.  It falls back to `system()` with a message when
  swapping isn't possible: more than 16 heap blocks, 'shell' not found,
  command over 126 characters, a vector Vim changed points into memory
  that would be swapped, or the swap file can't be written.
* Interrupt vectors are compared with a snapshot taken at startup; unused
  vectors hold garbage that may point anywhere (30h-31h even hold DOS's
  CP/M far JMP), so "points into Vim" alone gives false alarms.
  Int 22h (terminate address) is skipped: DOS EXEC points it at the
  caller, so after one `system()` fallback it points into Vim for good,
  and the child gets its own copy anyway.  Found on a real XT.
* The swap file is `$TEMP\VIMxxxx.SWP` (or `$TMP`, or the current
  directory), xxxx = PSP segment.  `vim_tempname()` isn't used: with no
  `$TMP`, `$TEMP`, `C:\TMP` or `C:\TEMP` it returns NULL, because
  `mch_isdir("")` is false on DOS.  (Upstream bug; it also affects
  filtering.  Not fixed yet.)
* Build option: `wmake -f Make_wat.mak SWAP=0` leaves it out (defines
  `XT_SWAP` otherwise).  `SWAPTRACE=1` makes the stub show its stage as
  a digit in the top right corner of a colour screen.

Measured in 86Box, Turbo C 2.0 MAKE from `:!MAKE`: 61,903 bytes available
before, 550,603 (DOS 3.3) and 540,763 (DOS 5) after.  Vim holds 1.8-2K
while the program runs.

## :make in the DOS build (src/feature.h, XT fork option)

MIN_FEAT leaves out QUICKFIX, so the 5.8 DOS build had no `:make`, `:cn`,
`:cp`, `:cl` or `:cf`.  `XT_QUICKFIX` (defined by Make_wat.mak unless
`QUICKFIX=0`) turns QUICKFIX back on; the only upstream change is that
`#if` in feature.h.  Cost: 10.5K of exe.  The DOS default 'errorformat'
already matches Turbo C (`Error FILE.C 12: message` via `%*[^ ] %f %l: %m`)
and 'makeef' is `vim##.err` in the current directory.

Tested with `xt/swaptest.sh`: `:make` on a file with errors on lines 6
and 7 lands on line 6, `:cn` on line 7 (DOS 3.3 and 5).

## Test environment (new, `xt/`)

* `xt/mkdisks.sh` makes 20 MB ST-506 hard disk images: MS-DOS 5.00
  (primary target) and 6.22 built straight from setup disk 1 (no SETUP
  run), and a copy of an existing DOS 3.3 image.
* `xt/run.sh` builds, injects vim.exe and the smoke test with mtools, and
  boots 86Box as an IBM 5160, 8088 at 4.77 MHz, 640K, CGA or MDA.
* `xt/smoke.sh` does the same hands-off: a flag file makes AUTOEXEC.BAT
  call `SMOKE.BAT`, which writes `RESULT.TXT`; the host polls the image
  with mtools, then stops 86Box.  Exit status 0 = pass.
* `xt/swaptest.sh [dos33|dos5|dos622]` builds a hello-world with Turbo C
  MAKE and TCC from inside Vim with `:!`, runs it, and checks Vim's buffer
  survived the swap; then checks `:make` and `:cn` land on the error
  lines of a broken file.
* `xt/check8086.sh` disassembles every object in vim.exe, Vim's and the
  C library modules from the link map, and fails on any 186+ opcode.
* `xt/smoke/SMOKE.BAT` runs Vim with `-c` ex commands and with a `-s`
  keystroke script, then compares the results with `CMPF.EXE`
  (`xt/dos/cmpf.c`): FC is not on PC DOS 3.3 and is compressed on the
  MS-DOS setup disks.

## Status

2026-10-09, IBM 5160 in 86Box 6.0, 8088 at 4.77 MHz, 640K:

| DOS          | Video | smoke.sh       |
|--------------|-------|----------------|
| MS-DOS 5.00  | CGA   | PASS           |
| MS-DOS 5.00  | MDA   | PASS           |
| MS-DOS 6.22  | CGA   | PASS           |
| PC DOS 3.30  | CGA   | PASS           |

`check8086.sh`: 113,238 instructions in 228 modules, no 186+ opcodes.
vim.exe is 374,466 bytes; load image 360,000 bytes (DGROUP 40K incl. 8K
stack).  Not yet checked: interactive use on screen, the Borland C++
reference build, and that the Borland/DJGPP paths still compile after
the `my*()` change in `mch_write()`.
