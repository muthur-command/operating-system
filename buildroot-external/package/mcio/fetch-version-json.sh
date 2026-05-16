#!/usr/bin/env bash
# Download MCOS version metadata and write canonical JSON.
# Strips accidental HTTP chunked framing left in static objects (leading "8e0" etc.).

set -euo pipefail

url=$1
out=$2
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

curl -fsSL "$url" -o "$tmp"

python3 - "$tmp" "$out" <<'PY'
import json
import sys

src, out = sys.argv[1], sys.argv[2]
data = open(src, "rb").read()

start = data.find(b"{")
end = data.rfind(b"}")
if start < 0 or end < start:
    print("fetch-version-json: no JSON object in response", file=sys.stderr)
    sys.exit(1)

obj = json.loads(data[start : end + 1])
with open(out, "w", encoding="utf-8") as fh:
    json.dump(obj, fh, indent=2)
    fh.write("\n")
PY
