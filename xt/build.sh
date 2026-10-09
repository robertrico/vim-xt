#!/bin/bash
#
# build.sh - build vim.exe and the small DOS test tools.  Needs only Open
# Watcom 2 (set WATCOM, or see xt/env.sh).  Extra arguments go to wmake,
# e.g. xt/build.sh DEBUG=1, xt/build.sh clean.
#
# Output: src/vim.exe, and build/dos/{cmpf,mcb,freemem,vect}.exe
#
set -e
. "$(dirname "$0")/env.sh"

(cd "$REPO_ROOT/src" && wmake -h -f Make_wat.mak "$@")
[ "$1" = clean ] && exit 0
mkdir -p "$BUILD_DIR/dos"
for t in cmpf mcb freemem vect; do
    (cd "$BUILD_DIR/dos" && wcl -zq -0 -ml -bt=dos -os -fe=$t.exe \
					"$XT_ROOT/dos/$t.c" >/dev/null)
done
ls -l "$REPO_ROOT/src/vim.exe"
