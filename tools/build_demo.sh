#!/usr/bin/env bash
# Build the demo module and the stock part overrides, then stage both in the
# game's user folder: overrides in development/, the module in modules/.
# Usage: tools/build_demo.sh <game folder> [game user folder]
# With no user folder it only builds, into build/.
set -euo pipefail
game=$1
user=${2:-}
repo=$(cd "$(dirname "$0")/.." && pwd)
build=$repo/build
rm -rf "$build"
mkdir -p "$build/override" "$build/mod"

# Every worn stock part, out of the game's own data.
"$repo/tools/build_parts.sh" "$game" "$build/override"
cp "$repo"/shaders/*.shd "$build/override/"

# The module: scripts compiled beside their sources, GFF files from JSON.
cp "$repo"/nss/*.nss "$repo"/demo/scripts/*.nss "$build/mod/"
nwn_script_comp --root "$game" -y -c "$build/mod"
for src in "$repo"/demo/src/*.json; do
    name=$(basename "$src" .json)
    nwn_gff -i "$src" -o "$build/mod/$name"
done
(cd "$build/mod" && nwn_erf -e MOD -f "$build/rgbdemo.mod" -c ./*)

if [ -z "$user" ]; then exit 0; fi
"$repo/tools/stage_demo.sh" "$build" "$user"
