#!/usr/bin/env bash
# Build the demo module and the stock part overrides, then stage both in the
# game's user folder: overrides in development/, the module in modules/.
# Usage: tools/build_demo.sh <game folder> <game user folder>
set -euo pipefail
game=$1
user=$2
repo=$(cd "$(dirname "$0")/.." && pwd)
build=$repo/build
rm -rf "$build"
mkdir -p "$build/plt" "$build/override" "$build/mod"

# Stock chest PLTs, out of the game's own data.
nwn_resman_extract --root "$game" -p _chest -d "$build/plt" >/dev/null
find "$build/plt" -type f ! -name '*.plt' -delete
python3 "$repo/tools/rgb_materials.py" "$build/plt" --out "$build/override"
cp "$repo"/shaders/*.shd "$build/override/"

# The module: scripts compiled beside their sources, GFF files from JSON.
cp "$repo"/nss/*.nss "$repo"/demo/scripts/*.nss "$build/mod/"
nwn_script_comp --root "$game" -y -c "$build/mod"
for src in "$repo"/demo/src/*.json; do
    name=$(basename "$src" .json)
    nwn_gff -i "$src" -o "$build/mod/$name"
done
(cd "$build/mod" && nwn_erf -e MOD -f "$build/rgbdemo.mod" -c ./*)

mkdir -p "$user/development" "$user/modules"
cp "$build"/override/* "$user/development/"
cp "$build/rgbdemo.mod" "$user/modules/"
echo "staged $(ls "$build/override" | wc -l) override files and rgbdemo.mod"
