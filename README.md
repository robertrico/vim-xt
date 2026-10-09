# Vim 5.8 for the IBM PC/XT

An unofficial fork of Vim 5.8, the last Vim with a 16-bit MS-DOS build,
for the IBM PC/XT 5160 and the 3270 PC 5271: an 8088 or V20 at 4.77 MHz,
640K, MDA or CGA, DOS 3.3 to 6.22.  It is not affiliated with the Vim
project.

The 5.8 DOS build was made with Borland C++.  This one is cross-compiled
with Open Watcom 2, so it can be built from a modern Linux or macOS machine
with free tools.  It adds:

* **Swap-out for `:!` and `:make`.**  Vim takes about 480K of the 640K, so a
  program started from it used to get about 60K.  Vim now writes itself to a
  swap file and leaves about 2K while the program runs (540K free for MAKE
  on DOS 5).
* **`:make`, `:cn`, `:cp`, `:cl`** (quickfix), which the 5.8 DOS build left
  out.  The default error format already matches Turbo C.
* **8086-only code**, checked by disassembling every object in the link.
* **Direct video** for MDA, CGA (without snow) and EGA/VGA.

Every change against upstream is listed in [PORTING.md](PORTING.md).

## Status

Runs on a real IBM 5160 (NEC V20, 640K, EGA card in CGA mode, MS-DOS 5.00), and passes the
smoke test there.  Automated tests pass in 86Box on an emulated 5160
(8088, 4.77 MHz) under MS-DOS 5.00 and 6.22 and PC DOS 3.30, with CGA and
MDA.  See [CHANGELOG.md](CHANGELOG.md) and the open problems in PORTING.md.

## Install on the XT

Get `vim-xt` from the latest build under the repository's Actions tab, or
build it yourself (below).  Copy the files to a floppy or CF card, then on
the XT:

    D:
    CD \VIM
    INSTALL

`INSTALL.BAT` copies Vim to `C:\VIM`, creates `C:\TEMP`, and runs the smoke
test, which should end with `SMOKE: PASS`.  Add these to `AUTOEXEC.BAT`:

    PATH C:\VIM;%PATH%
    SET TEMP=C:\TEMP

`TEMP` is where Vim puts its swap file during `:!` (about 400K free is
needed).  A `C:\VIM\_VIMRC` to start from:

    set bs=indent,eol,start
    set ru ai

## Using it with Turbo C

A `MAKEFILE` (the command line must start with a Tab):

    test.exe: test.c
    	tcc -IC:\TC\INCLUDE -LC:\TC\LIB test.c

In Vim, `:make` builds and jumps to the first error, `:cn` and `:cp` move
between errors, `:cl` lists them, and `:!test` runs the program.  The
swap-out takes a few seconds each way on a stock XT hard disk.

If `:!` prints `Not swapping Vim out: <reason>`, the command still runs,
but with little memory.  The reasons and fixes are in PORTING.md.

## Building

Needs [Open Watcom 2](https://github.com/open-watcom/open-watcom-v2).
Point `WATCOM` at the install (default `/opt/watcom`), then:

    xt/build.sh                 # src/vim.exe
    xt/build.sh DEBUG=1         # stack checking and debug info
    xt/build.sh SWAP=0          # leave out the swapper
    xt/build.sh QUICKFIX=0      # leave out :make and friends
    xt/build.sh clean
    xt/check8086.sh             # fail on any 186+ instruction

Without the scripts: `cd src && wmake -f Make_wat.mak`.

## Testing in 86Box

The `xt/` scripts build disk images with mtools and boot
[86Box](https://86box.net/) as an IBM 5160.  They need DOS media, which is
not in this repository; put your own in `media/` or name them in
`xt/local.sh` (see `xt/env.sh`):

* `DOS5_DISK1`, `DOS622_DISK1`: MS-DOS 5.00 / 6.22 setup disk 1 images.
* `DOS33_HDD`: an 86Box XT hard disk image with DOS 3.3 and Turbo C 2.0 in
  `C:\TC` (used for the MBR and by the swap test).

Then:

    xt/smoke.sh dos5 cga        # hands-off smoke test, exit 0 = pass
    xt/swaptest.sh dos5         # :!MAKE builds with Turbo C, :make finds errors
    xt/run.sh dos5 mda          # boot it and try it yourself

The scripts were written on macOS; `xt/mkdist.sh` uses macOS `cp -X` and
`dot_clean`.

## Branches

* `main`: this fork.
* `upstream`: the Vim 5.8 release tarballs plus official patches 5.8.001 to
  5.8.009, untouched (tag `vim-5.8.009`).  `git diff vim-5.8.009 main`
  shows every change.  The 5.8 tags in vim/vim-history are not used: they
  contain 6.0d alpha sources (see PORTING.md).

## License and credits

Vim is by Bram Moolenaar and the Vim contributors, and is Charityware: see
[LICENSE](LICENSE) and `runtime/doc/uganda.txt`.  If you like Vim, consider
a donation to the Kibaale Children's Centre through
[ICCF Holland](https://iccf-holland.org/).  This fork's own files are under
the same license.

`vim.exe` contains the Open Watcom C run-time library, whose source is
available under the Sybase Open Watcom Public License from
[github.com/open-watcom/open-watcom-v2](https://github.com/open-watcom/open-watcom-v2).

MS-DOS, PC DOS and Turbo C are not included and are not needed to build.
