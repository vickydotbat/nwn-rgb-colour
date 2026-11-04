#!/usr/bin/env bash
# Pack a release zip from a finished build: the hak, the demo module, a
# short readme and the census of skipped parts.
# Usage: tools/pack_release.sh <override folder> <demo .mod> <out folder>
set -euo pipefail
override=$(cd "$1" && pwd)
mod=$2
mkdir -p "$3"
out=$(cd "$3" && pwd)
repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
stage=$work/zip
mkdir -p "$stage/hak" "$stage/modules"

# The census is for builders to read, not a game resource. Pack a folder
# of links, since thousands of names overflow one command line.
mkdir "$work/hak"
find "$override" -maxdepth 1 -type f ! -name census.txt -exec ln -s -t "$work/hak" {} +
nwn_erf -e HAK -f "$stage/hak/rgbcolour.hak" -c "$work/hak"
cp "$mod" "$stage/modules/rgbdemo.mod"
cp "$override/census.txt" "$stage/census.txt"
cp "$repo/tools/release-readme.txt" "$stage/README.txt"
# What a builder needs to use this in their own module: the docs, the
# scripts to copy, the shaders, the palette table and the convert tool.
mkdir -p "$stage/source/docs" "$stage/source/nss" "$stage/source/demo/scripts" "$stage/source/shaders" \
    "$stage/source/tools" "$stage/source/data"
cp "$repo/README.md" "$repo/LICENSE" "$stage/source/"
cp "$repo"/docs/*.md "$stage/source/docs/"
cp "$repo"/nss/*.nss "$stage/source/nss/"
cp "$repo"/demo/scripts/*.nss "$stage/source/demo/scripts/"
cp "$repo"/shaders/*.shd "$stage/source/shaders/"
cp "$repo/tools/rgb_materials.py" "$stage/source/tools/"
cp "$repo"/data/*.2da "$stage/source/data/"
# Screenshots worth showing go in docs/screenshots.
shots=("$repo"/docs/screenshots/*.png)
if [ -e "${shots[0]}" ]; then
    mkdir -p "$stage/screenshots"
    cp "$repo"/docs/screenshots/*.png "$stage/screenshots/"
fi
rm -f "$out/nwn-rgb-colour.zip"
python3 -c 'import shutil, sys; shutil.make_archive(sys.argv[1], "zip", sys.argv[2])' "$out/nwn-rgb-colour" "$stage"
echo "wrote $out/nwn-rgb-colour.zip"
