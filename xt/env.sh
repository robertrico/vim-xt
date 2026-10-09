# Common settings for the xt/ scripts.  Source, don't run.
# Override any of these in the environment.

XT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$XT_ROOT/.." && pwd)
BUILD_DIR=${BUILD_DIR:-$REPO_ROOT/build}

# Open Watcom 2 install (host binaries in armo64/, bino64/, binl64/ ...)
WATCOM=${WATCOM:-$HOME/Development/tooling/openwatcom2}
case "$(uname -s)-$(uname -m)" in
    Darwin-arm64)  WATCOM_BIN=$WATCOM/armo64 ;;
    Darwin-x86_64) WATCOM_BIN=$WATCOM/bino64 ;;
    Linux-x86_64)  WATCOM_BIN=$WATCOM/binl64 ;;
    Linux-aarch64) WATCOM_BIN=$WATCOM/arml64 ;;
    *)             WATCOM_BIN=$WATCOM/binl ;;
esac
export WATCOM INCLUDE=$WATCOM/h PATH=$WATCOM_BIN:$PATH

EIGHTYSIXBOX=${EIGHTYSIXBOX:-/Applications/86Box.app/Contents/MacOS/86Box}

# Source media.  Not in the repo: bring your own.
DOS33_HDD=${DOS33_HDD:-$HOME/Development/86box/drives/dos330_dev.img}
DOS5_DISK1=${DOS5_DISK1:-"$HOME/Development/86box/media/dos/msdos500_360k/Microsoft MS-DOS 5.00 (5.25-360k)/Disk01.img"}
DOS622_DISK1=${DOS622_DISK1:-$HOME/Development/86box/media/dos/MSDOS622-1440K-DISK1.img}

# Disk geometry for the ST-506 XT controller: 615 cyl, 4 heads, 17 spt
# (20 MB, IBM type 2).  The DOS partition starts at sector 17.
HDD_CYL=615
HDD_HEADS=4
HDD_SPT=17
PART_OFFSET=$((17 * 512))
