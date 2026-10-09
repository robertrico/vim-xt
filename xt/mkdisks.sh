#!/bin/bash
#
# mkdisks.sh - make the 20 MB XT hard disk images used for testing.
#
#   build/dos5.img    MS-DOS 5.00 (primary target), from setup disk 1
#   build/dos622.img  MS-DOS 6.22, from setup disk 1
#   build/dos33.img   copy of an existing PC/MS-DOS 3.3 hard disk image
#
# The MS-DOS images are made without running SETUP: the boot code comes from
# the setup floppy, the BPB from mformat, then IO.SYS, MSDOS.SYS and
# COMMAND.COM are copied in.
#
# Existing images are kept; use -f to rebuild them.
#
set -e
. "$(dirname "$0")/env.sh"

force=0
[ "$1" = "-f" ] && force=1
mkdir -p "$BUILD_DIR"
export MTOOLS_SKIP_CHECK=1 MTOOLS_NO_VFAT=1

make_dos33() {
    local img=$BUILD_DIR/dos33.img
    [ -f "$img" ] && [ $force = 0 ] && { echo "keep $img"; return; }
    [ -f "$DOS33_HDD" ] || { echo "no DOS 3.3 image: set DOS33_HDD"; return 1; }
    cp "$DOS33_HDD" "$img"
    echo "made $img (from $DOS33_HDD)"
}

make_msdos() {
    local name=$1 disk1=$2
    local img=$BUILD_DIR/$name.img
    local tmp=$BUILD_DIR/tmp_$name
    [ -f "$img" ] && [ $force = 0 ] && { echo "keep $img"; return; }
    [ -f "$disk1" ] || { echo "no setup disk 1 for $name: $disk1"; return 1; }
    [ -f "$DOS33_HDD" ] || { echo "need DOS33_HDD for its MBR code"; return 1; }
    rm -rf "$tmp"; mkdir -p "$tmp"

    # Blank disk, MBR boot code from the DOS 3.3 disk, one active FAT16
    # partition from cylinder 0 head 1 to cylinder 613 (DOS keeps the last
    # cylinder free, like FDISK does).
    local total=$((HDD_CYL * HDD_HEADS * HDD_SPT))
    local psize=$(((HDD_CYL - 1) * HDD_HEADS * HDD_SPT - HDD_SPT))
    dd if=/dev/zero of="$img" bs=512 count=$total 2>/dev/null
    python3 -I - "$img" "$DOS33_HDD" "$psize" <<'PY'
import struct, sys
img, src, psize = sys.argv[1], sys.argv[2], int(sys.argv[3])
code = open(src, 'rb').read(446)
heads, spt, start = 4, 17, 17
end = start + psize - 1
def chs(lba):
    c, r = divmod(lba, heads * spt)
    h, s = divmod(r, spt)
    return bytes([h, ((c >> 2) & 0xc0) | (s + 1), c & 0xff])
entry = bytes([0x80]) + chs(start) + bytes([0x04]) + chs(end) \
        + struct.pack('<II', start, psize)
mbr = code + entry + bytes(48) + b'\x55\xaa'
with open(img, 'r+b') as f:
    f.write(mbr)
PY

    # Format with the setup floppy's boot code; mformat fills in the BPB.
    dd if="$disk1" of="$tmp/boot.bin" bs=512 count=1 2>/dev/null
    mformat -i "$img@@$PART_OFFSET" -T "$psize" -h $HDD_HEADS -s $HDD_SPT \
	-H $HDD_SPT -B "$tmp/boot.bin" ::
    # BPB drive number: hard disk.
    printf '\x80' | dd of="$img" bs=1 seek=$((PART_OFFSET + 0x24)) \
	conv=notrunc 2>/dev/null

    # IO.SYS and MSDOS.SYS must be the first two directory entries, so no
    # volume label (mformat -v would put it first).
    for f in IO.SYS MSDOS.SYS COMMAND.COM FORMAT.COM; do
	mcopy -i "$disk1" "::$f" "$tmp/$f"
	mcopy -i "$img@@$PART_OFFSET" "$tmp/$f" "::$f"
    done
    mattrib -i "$img@@$PART_OFFSET" +s +h +r ::IO.SYS ::MSDOS.SYS

    printf 'FILES=20\r\nBUFFERS=20\r\n' > "$tmp/CONFIG.SYS"
    printf '@ECHO OFF\r\nPATH=C:\\;C:\\VIM\r\nPROMPT $P$G\r\n' > "$tmp/AUTOEXEC.BAT"
    mcopy -i "$img@@$PART_OFFSET" "$tmp/CONFIG.SYS" "$tmp/AUTOEXEC.BAT" ::
    rm -rf "$tmp"
    echo "made $img"
}

make_msdos dos5 "$DOS5_DISK1"
make_msdos dos622 "$DOS622_DISK1"
make_dos33
