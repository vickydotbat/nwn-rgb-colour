#!/usr/bin/env bash
# Build the release zip for the v* tag on HEAD and attach it to a draft
# GitHub Release. The maintainer reads the draft, publishes it, and uploads
# the same zip to the Neverwinter Vault.
# Usage: tools/release.sh <game folder>
set -euo pipefail
game=$1
repo=$(cd "$(dirname "$0")/.." && pwd)
tag=$(git -C "$repo" describe --tags --exact-match --match 'v*' HEAD 2>/dev/null) || {
    echo "HEAD has no v* tag. Tag main first, for example: git tag v0.1" >&2
    exit 1
}
"$repo/tools/build_demo.sh" "$game"
"$repo/tools/pack_release.sh" "$repo/build/override" "$repo/build/rgbdemo.mod" "$repo/dist"
if gh release view "$tag" >/dev/null 2>&1; then
    gh release upload "$tag" "$repo/dist/nwn-rgb-colour.zip" --clobber
else
    gh release create "$tag" "$repo/dist/nwn-rgb-colour.zip" --verify-tag --draft --title "$tag" --notes ""
fi
echo "$tag: zip attached to the release. Publish it on GitHub, then upload dist/nwn-rgb-colour.zip to the Vault."
