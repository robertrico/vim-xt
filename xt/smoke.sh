#!/bin/bash
#
# smoke.sh - run the DOS smoke test in 86Box without touching the keyboard.
#
# Usage: xt/smoke.sh [-n] [dos5|dos622|dos33] [cga|mda]
#
# Builds and injects (unless -n), boots with AUTORUN set so AUTOEXEC.BAT
# runs SMOKE.BAT, waits for SMOKE.BAT to write RESULT.TXT, stops 86Box and
# prints the verdict.  Exit status 0 = pass.
#
. "$(dirname "$0")/env.sh"

nobuild=
[ "$1" = "-n" ] && { nobuild=-n; shift; }
os=${1:-dos5}
video=${2:-cga}
D="$BUILD_DIR/$os.img@@$PART_OFFSET"
export MTOOLS_SKIP_CHECK=1 MTOOLS_NO_VFAT=1
TIMEOUT=${SMOKE_TIMEOUT:-600}

# Build and inject in the foreground so a build error stops us here.
"$XT_ROOT/run.sh" -i -s $nobuild "$os" "$video" || exit 2
"$XT_ROOT/run.sh" -n -s "$os" "$video" > "$BUILD_DIR/86box-$os-$video.log" 2>&1 &
pid=$!

result=""
start=$(date +%s)
while [ $(( $(date +%s) - start )) -lt "$TIMEOUT" ]; do
    sleep 5
    result=$(mtype -i "$D" ::VIM/SMOKE/RESULT.TXT 2>/dev/null | tr -d '\r')
    [ -n "$result" ] && break
    kill -0 $pid 2>/dev/null || break
done
sleep 2		# let DOS finish the batch file
# run.sh execs 86Box, so $pid is the emulator.  It may ignore SIGTERM
# while showing a dialog; the disk image is done with by now.
kill $pid 2>/dev/null
sleep 2
kill -9 $pid 2>/dev/null
wait $pid 2>/dev/null

if [ -z "$result" ]; then
    echo "SMOKE: no result after $(( $(date +%s) - start ))s ($os $video)"
    exit 2
fi
for f in CMP1.TXT CMP2.TXT; do
    mtype -i "$D" "::VIM/SMOKE/$f" 2>/dev/null | tr -d '\r'
done
echo "$result ($os $video, $(( $(date +%s) - start ))s)"
case "$result" in *PASS*) exit 0 ;; *) exit 1 ;; esac
