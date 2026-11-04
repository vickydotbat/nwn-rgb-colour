#!/usr/bin/env bash
# Stage a built demo in the game's user folder for a live check: the
# overrides in development/, the module in modules/ and the hak in hak/.
# Usage: tools/stage_demo.sh <build folder> <game user folder>
set -euo pipefail
build=$1
user=$2
repo=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$user/development" "$user/modules" "$user/hak"
# Copying alone would leave a file an older build staged and this one no
# longer makes. Remove what the last run staged, by its list, first.
staged="$user/development/rgb_staged.txt"
if [ -f "$staged" ]; then
    (cd "$user/development" && xargs -a "$staged" -d '\n' rm -f --)
fi
cp "$build"/override/* "$user/development/"
(cd "$build/override" && ls) > "$staged"
cp "$build/rgbdemo.mod" "$user/modules/"
# The module lists rgbcolour.hak and won't load without it. The copies in
# development/ outrank the hak, so a quick fix there shows without a repack.
"$repo/tools/pack_release.sh" "$build/override" "$build/rgbdemo.mod" "$build/dist" >/dev/null
unzip -o -q -j "$build/dist/nwn-rgb-colour.zip" hak/rgbcolour.hak -d "$user/hak"
echo "staged $(wc -l < "$staged") override files and rgbdemo.mod"
