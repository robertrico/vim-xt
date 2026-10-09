#!/bin/bash
#
# swaptest.sh - check that :! swaps Vim out: build a hello-world with
# Turbo C's MAKE and TCC from inside Vim.  Turbo C 2.0 comes from C:\TC on
# the DOS 3.3 image and is copied to the other images when missing.
#
# Usage: xt/swaptest.sh [-n] [dos33|dos5|dos622]	(-n: don't rebuild)
#
# Inside Vim:  :!MAKE   :!MCB (memory map during :!)   :!HELLO   :w CHECK.C
# Pass: HELLO.EXE built and prints, CHECK.C == HELLO.C (Vim's buffer came
# back intact).  Results are printed; exit status 0 = pass.
#
. "$(dirname "$0")/env.sh"
export MTOOLS_SKIP_CHECK=1 MTOOLS_NO_VFAT=1

nobuild=0
[ "$1" = "-n" ] && { nobuild=1; shift; }
os=${1:-dos33}
[ $nobuild = 1 ] || "$XT_ROOT/run.sh" -i "$os" cga >/dev/null || exit 2
img=$BUILD_DIR/swaptest.img
D="$img@@$PART_OFFSET"
[ -f "$BUILD_DIR/$os.img" ] || "$XT_ROOT/mkdisks.sh" >/dev/null
cp "$BUILD_DIR/$os.img" "$img"
mmd -i "$D" ::VIM </dev/null 2>/dev/null
mcopy -o -i "$D" "$BUILD_DIR/dos/cmpf.exe" ::VIM/CMPF.EXE </dev/null
if ! mdir -i "$D" ::TC/TCC.EXE </dev/null >/dev/null 2>&1; then
    tc=$(mktemp -d)
    mcopy -s -i "$BUILD_DIR/dos33.img@@$PART_OFFSET" ::TC "$tc/" </dev/null
    mcopy -s -i "$D" "$tc/TC" :: </dev/null
    rm -rf "$tc"
fi
mcopy -o -i "$D" "$REPO_ROOT/src/vim.exe" ::VIM/VIM.EXE </dev/null
for t in mcb vect freemem; do
    (cd "$BUILD_DIR/dos" && wcl -zq -0 -ml -bt=dos -os -fe=$t.exe \
				    "$XT_ROOT/dos/$t.c" >/dev/null) || exit 2
    mcopy -o -i "$D" "$BUILD_DIR/dos/$t.exe" "::VIM/$(echo $t | tr a-z A-Z).EXE" </dev/null
done

tmp=$(mktemp -d)
printf '#include <stdio.h>\r\n\r\nint main()\r\n{\r\n    printf("hello from tcc\\n");\r\n    return 0;\r\n}\r\n' > "$tmp/HELLO.C"
printf 'hello.exe: hello.c\r\n\ttcc -IC:\\TC\\INCLUDE -LC:\\TC\\LIB hello.c\r\n' > "$tmp/MAKEFILE"
printf ':!MAKE > MK.TXT\r\r:!MCB > MCB.TXT\r\r:!HELLO > OUT.TXT\r\r:w CHECK.C\r:q!\r' > "$tmp/K.KEY"
printf '@ECHO OFF\r\npath=c:\\bin;c:\\tc;C:\\VIM\r\nMD \\MKT\r\nCD \\MKT\r\nVIM -u NONE -s K.KEY HELLO.C\r\nCMPF HELLO.C CHECK.C > CMP.TXT\r\nECHO done > DONE.TXT\r\n' > "$tmp/AUTOEXEC.BAT"
mmd -i "$D" ::MKT </dev/null
for f in HELLO.C MAKEFILE K.KEY; do
    mcopy -o -i "$D" "$tmp/$f" "::MKT/$f" </dev/null
done
mcopy -o -i "$D" "$tmp/AUTOEXEC.BAT" ::AUTOEXEC.BAT </dev/null
rm -rf "$tmp"

vm=$BUILD_DIR/vm/swaptest
mkdir -p "$vm"
sed "s#^hdd_01_fn = .*#hdd_01_fn = $img#" "$BUILD_DIR/vm/dos33-cga/86box.cfg" \
    > "$vm/86box.cfg" 2>/dev/null \
    || sed "s#^hdd_01_fn = .*#hdd_01_fn = $img#" "$BUILD_DIR/vm/dos5-cga/86box.cfg" > "$vm/86box.cfg"
"$EIGHTYSIXBOX" -P "$vm" >/dev/null 2>&1 &
pid=$!
start=$(date +%s)
while [ $(( $(date +%s) - start )) -lt 400 ]; do
    sleep 5
    mtype -i "$D" ::MKT/DONE.TXT </dev/null >/dev/null 2>&1 && break
    kill -0 $pid 2>/dev/null || break
done
sleep 2
kill -9 $pid 2>/dev/null
wait $pid 2>/dev/null
echo "($(( $(date +%s) - start ))s)"
for f in MK MCB OUT CMP; do
    echo "== $f.TXT"
    mtype -i "$D" "::MKT/$f.TXT" </dev/null 2>&1 | LC_ALL=C tr -d '\r' \
	| LC_ALL=C tr -c '[:print:]\n' '?'
done
out=$(mtype -i "$D" ::MKT/OUT.TXT </dev/null 2>/dev/null | tr -d '\r')
cmp=$(mtype -i "$D" ::MKT/CMP.TXT </dev/null 2>/dev/null | tr -d '\r')
case "$out$cmp" in
    "hello from tcc"*"are the same"*) echo "SWAPTEST: PASS"; exit 0 ;;
    *) echo "SWAPTEST: FAIL"; exit 1 ;;
esac
