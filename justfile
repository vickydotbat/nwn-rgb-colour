# Run inside the dev shell: `nix develop`.

# The game folder. Empty means the compiler finds the install itself.
nwn_root := env_var_or_default("NWN_ROOT", "")

# Unit tests. The compile tests need the game data, as `compile` does.
test:
    python3 -m unittest discover -s tests -v

# Compile every script under a folder. A broken script fails the run
# and the compiler names its file and line.
compile folder="demo" out="build/ncs":
    #!/usr/bin/env bash
    set -euo pipefail
    if ! find "{{folder}}" -name '*.nss' 2>/dev/null | grep -q .; then
        echo "no scripts under {{folder}}"
        exit 0
    fi
    root=()
    if [ -n "{{nwn_root}}" ]; then root=(--root "{{nwn_root}}"); fi
    # nss/ holds the includes. Compiled files go to build/, never beside the source.
    mkdir -p "{{out}}"
    nwn_script_comp "${root[@]}" --dirs nss -d "{{out}}" -y -R -c "{{folder}}"

# Build the overrides and the demo module, and stage them in the game's
# user folder (development/ and modules/) for a live check.
demo game user:
    tools/build_demo.sh "{{game}}" "{{user}}"

# Make a builder's own PLT parts RGB-ready: a material and a slot mask
# for each .plt in the folder, written beside it.
convert folder:
    python3 tools/rgb_materials.py "{{folder}}" --out "{{folder}}"

# Make every worn stock part RGB-ready, from the game folder's models and
# PLTs. census.txt in the output lists each part it skipped and why.
build game out="build/parts":
    tools/build_parts.sh "{{game}}" "{{out}}"

# Build the release zip for the v* tag on HEAD and attach it to a draft
# GitHub Release. Run on main, on a machine with the game installed.
release game:
    tools/release.sh "{{game}}"
