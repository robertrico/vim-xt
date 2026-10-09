# Changelog

Changes in this fork against Vim 5.8 with patches 5.8.001 to 5.8.009
(tag `vim-5.8.009`).  Details and reasons are in PORTING.md.

## Unreleased

### Added
- Open Watcom 2 build: `src/Make_wat.mak` (large model, 8086 only), and
  `xt/build.sh`.
- Direct video for MDA, CGA and EGA/VGA, replacing Borland's conio, with
  retrace waits on a real CGA to avoid snow.
- `src/dosswap.asm`: Vim swaps itself out to `$TEMP` for `:!` and `:make`,
  leaving about 2K resident.  Build with `SWAP=0` to leave it out.
- Quickfix (`:make`, `:cn`, `:cp`, `:cl`, `:cf`) in the DOS build
  (`XT_QUICKFIX`; `QUICKFIX=0` to leave it out).
- `:version` names the fork and carries the Open Watcom run-time notice.
- Test harness in `xt/`: 86Box disk images, a hands-off smoke test, a
  Turbo C swap and `:make` test, and an 8086 opcode check.  `INSTALL.BAT`
  and `xt/mkdist.sh` for putting it on a real machine.
- GitHub Actions build with the 8086 check.

### Changed
- Ctrl-Break, Ctrl-C and critical-error handlers rewritten for Watcom; all
  three vectors are now restored on exit and around a shell.

### Fixed
- `:!` refused to swap after one command had run without swapping, because
  DOS left int 22h pointing into Vim.  Found on a real 5160.
