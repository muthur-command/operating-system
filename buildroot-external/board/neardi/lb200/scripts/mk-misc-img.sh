#!/bin/bash
# Create misc.img with Android A/B metadata (AvbABData @ offset 0x800).
# Matches Rockchip SPL expectations on first flash (slot _a bootable).
set -euo pipefail

binaries_dir="${1:?binaries dir}"
out="${binaries_dir}/misc.img"

python3 - "${out}" <<'PY'
import struct
import sys
import zlib

out = sys.argv[1]
misc_size = 48 * 1024
ab_off = 0x800

magic = b"\0AB0"

def slot(priority, tries, successful):
    return struct.pack("BBBB", priority, tries, successful, 0)

# AvbABData (32 bytes) per android_avb/avb_ab_flow.h
body = (
    magic
    + struct.pack("BB", 1, 0)  # version_major, version_minor
    + b"\0\0"  # reserved1
    + slot(15, 7, 0)
    + slot(14, 7, 0)
    + b"\0"  # last_boot
    + b"\0" * 11  # reserved2
)
crc = struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)
ab_data = body + crc

if len(ab_data) != 32:
    raise SystemExit(f"unexpected AvbABData size {len(ab_data)}")

img = bytearray(misc_size)
img[ab_off:ab_off + len(ab_data)] = ab_data

with open(out, "wb") as f:
    f.write(img)
PY

echo "Created ${out} (A/B metadata @ 0x800, slot_a active)"
