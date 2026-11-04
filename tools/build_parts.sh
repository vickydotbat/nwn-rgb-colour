#!/usr/bin/env bash
# Make every worn stock part RGB-ready: pull the part models and PLTs out of
# the game, then give each part its own material and slot mask.
# Usage: tools/build_parts.sh <game folder> <out folder>
set -euo pipefail
game=$1
out=$2
repo=$(cd "$(dirname "$0")/.." && pwd)
raw=$(mktemp -d)
trap 'rm -rf "$raw"' EXIT

# The premium modules keep their worn parts in their own resource haks.
haks=$(printf '%s,' "$game"/data/hk/{km,sg,ww}_resources.hak)
for slot in belt bicep chest foot fore hand leg neck pelvis robe shin sho; do
    nwn_resman_extract --root "$game" --erfs "${haks%,}" --quiet -p "_$slot" -d "$raw" >/dev/null
done
python3 "$repo/tools/rgb_build.py" "$raw" "$raw" --out "$out"
