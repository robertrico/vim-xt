#!/bin/bash
#
# mkdist.sh - put vim.exe, CMPF.EXE, the smoke test and INSTALL.BAT in one
# directory for a real machine, e.g. on a CF card read by an XT-IDE.
#
# Usage: xt/mkdist.sh [dest]	(default build/dist; VIM\ is made inside)
# On the XT:  D:  CD \VIM  INSTALL
#
set -e
. "$(dirname "$0")/env.sh"

dest=${1:-$BUILD_DIR/dist}
out=$dest/VIM
[ -f "$REPO_ROOT/src/vim.exe" ] || { echo "build vim.exe first (xt/run.sh -i)"; exit 1; }
[ -f "$BUILD_DIR/dos/cmpf.exe" ] || { echo "no cmpf.exe (xt/run.sh -i)"; exit 1; }

mkdir -p "$out/SMOKE"
# cp -X: no extended attributes, so macOS writes no ._ files on FAT.
cp -X "$REPO_ROOT/src/vim.exe" "$out/VIM.EXE"
cp -X "$BUILD_DIR/dos/cmpf.exe" "$out/CMPF.EXE"
# MCB lists DOS memory blocks: :!MCB shows Vim swapped out to ~2K.
(cd "$BUILD_DIR/dos" && wcl -zq -0 -ml -bt=dos -os -fe=mcb.exe "$XT_ROOT/dos/mcb.c" >/dev/null)
cp -X "$BUILD_DIR/dos/mcb.exe" "$out/MCB.EXE"
cp -X "$XT_ROOT/dist/INSTALL.BAT" "$out/INSTALL.BAT"
for f in SMOKE.BAT IN1.TXT EXP1.TXT IN2.TXT EXP2.TXT T2.KEY; do
    cp -X "$XT_ROOT/smoke/$f" "$out/SMOKE/$f"
done
# macOS still tags new files itself; on FAT that becomes ._NAME files,
# which INSTALL.BAT's COPY *.* would carry onto C:.  Strip them.
dot_clean -m "$out"
sync
ls -la "$out" "$out/SMOKE"
