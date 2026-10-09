#!/bin/bash
#
# check8086.sh - make sure vim.exe has no 80186+ instructions.
#
# Disassembles every object linked into vim.exe (Vim's own objects plus the
# C library modules named in the link map) and flags 186/286 opcodes:
# pusha popa bound enter leave ins outs, push imm, imul imm, shift/rotate
# by imm8, and any 0F-prefixed opcode.  Exit status 0 = clean.
#
set -e
. "$(dirname "$0")/env.sh"

SRC=$REPO_ROOT/src
MAP=$SRC/objwat/vim.map
[ -f "$MAP" ] || { echo "no $MAP: build first"; exit 2; }
work=$(mktemp -d "${TMPDIR:-/tmp}/check8086.XXXXXX")
trap 'rm -rf "$work"' EXIT

# Library modules from the map, e.g. "dos/clibl.lib(sprintf.c)".
grep '^Module:' "$MAP" | grep -v objwat \
    | sed -E 's/.*lib286\/(dos\/)?([a-z0-9]+\.lib)\(([^)]*)\).*/\1\2 \3/' \
    | sort -u > "$work/mods"
for lib in $(awk '{print $1}' "$work/mods" | sort -u); do
    mkdir -p "$work/x"
    (cd "$work/x" && wlib -q -x "$WATCOM/lib286/$lib" >/dev/null)
done
{
    while read -r lib mod; do
	f=$work/x/${mod%.*}.o
	[ -f "$f" ] || { echo "MISSING $mod" >&2; continue; }
	wdis "$f"
    done < "$work/mods"
    for o in "$SRC"/objwat/*.obj; do wdis "$o"; done
} > "$work/dis.txt" 2>"$work/err"
if [ -s "$work/err" ]; then cat "$work/err"; exit 2; fi

python3 -I - "$work/dis.txt" <<'PY'
import re, sys
B186 = {'pusha', 'popa', 'bound', 'enter', 'leave',
        'insb', 'insw', 'outsb', 'outsw'}
OPC186 = {'0F', '60', '61', '62', '68', '69', '6A', '6B',
          '6C', '6D', '6E', '6F', 'C0', 'C1', 'C8', 'C9'}
PREFIX = {'F3', 'F2', '2E', '26', '36', '3E', 'F0'}
mod, code, n, bad, mods = None, False, 0, [], set()
for line in open(sys.argv[1], errors='replace'):
    if line.startswith('Module:'):
        mod = line.split()[1].split('/')[-1]
    elif line.startswith('Segment:'):
        code = 'TEXT' in line.split()[1]
    if not code:
        continue
    m = re.match(r'^[0-9A-F]{4}  ((?:[0-9A-F]{2} ?)+)\t+([a-z][a-z0-9]*)',
                 line)
    if not m:
        continue
    n += 1
    mods.add(mod)
    b = m.group(1).split()
    i = 0
    while i < len(b) - 1 and b[i] in PREFIX:
        i += 1
    if m.group(2) in B186 or b[i] in OPC186:
        bad.append('%s: %s' % (mod, line.rstrip()))
print('checked %d instructions in %d modules' % (n, len(mods)))
for x in bad[:50]:
    print(x)
if bad:
    print('FAIL: %d 186+ instructions' % len(bad))
    sys.exit(1)
print('OK: 8086/8088 only')
PY
