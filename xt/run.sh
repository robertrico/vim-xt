#!/bin/bash
#
# run.sh - build vim.exe, put it on a test disk image and boot 86Box.
#
# Usage: xt/run.sh [-n] [dos5|dos622|dos33] [cga|mda]
#	-n	don't build, only inject and boot
#	-i	only build and inject, don't boot
#	-s	run the smoke test from AUTOEXEC.BAT on boot (see xt/smoke.sh)
#
# Defaults: dos5 cga.  The emulated machine is an IBM 5160 (XT), 8088 at
# 4.77 MHz, 640K, ST-506 20 MB disk.  On the C: drive you get:
#	C:\VIM\VIM.EXE	C:\VIM\CMPF.EXE	C:\VIM\SMOKE\SMOKE.BAT ...
# and C:\VIM is on the PATH.  Run the smoke test with
#	CD \VIM\SMOKE
#	SMOKE
#
set -e
. "$(dirname "$0")/env.sh"

build=1 boot=1 auto=0
while [ $# -gt 0 ]; do
    case "$1" in
	-n) build=0 ;;
	-i) boot=0 ;;
	-s) auto=1 ;;
	*) break ;;
    esac
    shift
done
os=${1:-dos5}
video=${2:-cga}
img=$BUILD_DIR/$os.img
export MTOOLS_SKIP_CHECK=1 MTOOLS_NO_VFAT=1
D="$img@@$PART_OFFSET"

case "$video" in
    cga|mda) ;;
    *) echo "video must be cga or mda"; exit 1 ;;
esac

if [ $build = 1 ]; then
    (cd "$REPO_ROOT/src" && wmake -h -f Make_wat.mak)
    mkdir -p "$BUILD_DIR/dos"
    (cd "$BUILD_DIR/dos" && wcl -zq -0 -ml -bt=dos -os -fe=cmpf.exe \
					    "$XT_ROOT/dos/cmpf.c" >/dev/null)
fi
[ -f "$img" ] || "$XT_ROOT/mkdisks.sh"

# Inject.  mtools asks on the terminal when a name already exists, so
# never let it read the keyboard: mcopy -o overwrites, and directories are
# only made when missing.
mtools_dir() {
    mdir -i "$D" "::$1" </dev/null >/dev/null 2>&1 || mmd -i "$D" "::$1" </dev/null
}
mtools_dir VIM
mtools_dir VIM/SMOKE
mcopy -o -i "$D" "$REPO_ROOT/src/vim.exe" ::VIM/VIM.EXE </dev/null
mcopy -o -i "$D" "$BUILD_DIR/dos/cmpf.exe" ::VIM/CMPF.EXE </dev/null
for f in "$XT_ROOT"/smoke/*; do
    mcopy -o -i "$D" "$f" "::VIM/SMOKE/$(basename "$f")" </dev/null
done
# Leftovers from an earlier run would hide a failure.
for f in T1.TXT T2.TXT CMP1.TXT CMP2.TXT RESULT.TXT AUTORUN; do
    mdel -i "$D" "::VIM/SMOKE/$f" </dev/null 2>/dev/null || true
done
if [ $auto = 1 ]; then
    printf 'x\r\n' > "$BUILD_DIR/autorun.tmp"
    mcopy -o -i "$D" "$BUILD_DIR/autorun.tmp" ::VIM/SMOKE/AUTORUN </dev/null
    rm -f "$BUILD_DIR/autorun.tmp"
fi

# Make sure C:\VIM is on the PATH and the smoke test can start itself.
tmp=$(mktemp -d)
mcopy -o -i "$D" ::AUTOEXEC.BAT "$tmp/AUTOEXEC.BAT" 2>/dev/null </dev/null \
    || : > "$tmp/AUTOEXEC.BAT"
changed=0
# An AUTOEXEC.BAT without a final newline would glue our line onto its last.
if [ -s "$tmp/AUTOEXEC.BAT" ] && [ "$(tail -c 1 "$tmp/AUTOEXEC.BAT" | od -An -c | tr -d ' ')" != '\n' ]; then
    printf '\r\n' >> "$tmp/AUTOEXEC.BAT"
fi
if ! grep -qi 'C:\\VIM' "$tmp/AUTOEXEC.BAT"; then
    printf 'PATH %%PATH%%;C:\\VIM\r\n' >> "$tmp/AUTOEXEC.BAT"
    changed=1
fi
if ! grep -qi 'AUTORUN' "$tmp/AUTOEXEC.BAT"; then
    printf 'IF EXIST C:\\VIM\\SMOKE\\AUTORUN CALL C:\\VIM\\SMOKE\\AUTO.BAT\r\n' \
	>> "$tmp/AUTOEXEC.BAT"
    changed=1
fi
[ $changed = 1 ] && mcopy -o -i "$D" "$tmp/AUTOEXEC.BAT" ::AUTOEXEC.BAT </dev/null
rm -rf "$tmp"
echo "injected vim.exe into $img"

[ $boot = 1 ] || exit 0

# Two emulators writing one disk image would corrupt it.
if pgrep -f "86Box.*-P $BUILD_DIR/vm/$os-" >/dev/null; then
    echo "86Box is already running on $os.img; close it first"
    exit 1
fi

# One 86Box VM directory per os/video pair, so NVR and window state stick.
vm=$BUILD_DIR/vm/$os-$video
mkdir -p "$vm"
cat > "$vm/86box.cfg" <<EOF
[Machine]
machine = ibmxt86
cpu_family = 8088
cpu_speed = 4772728
cpu_multi = 1
cpu_use_dynarec = 0
mem_size = 640

[Video]
gfxcard = $video

[Input devices]
keyboard_type = keyboard_pc_xt
mouse_type = none

[Storage controllers]
fdc = fdc_xt
hdc_1 = st506_xt

[Hard disks]
hdd_01_fn = $img
hdd_01_mfm_channel = 0
hdd_01_parameters = $HDD_SPT, $HDD_HEADS, $HDD_CYL, 0, mfm
hdd_01_speed = ramdisk

[General]
confirm_exit = 0
confirm_reset = 0
confirm_save = 0
hide_tool_bar = 1
vid_resize = 1
EOF
exec "$EIGHTYSIXBOX" -P "$vm"
