# Run inside the dev shell: `nix develop`.

# The game folder. Empty means the compiler finds the install itself.
nwn_root := env_var_or_default("NWN_ROOT", "")

# Unit tests: no game install needed beyond what `compile` uses.
test:
    python3 -m unittest discover -s tests -v

# Compile every script under a folder. A broken script fails the run
# and the compiler names its file and line.
compile folder="demo":
    #!/usr/bin/env bash
    set -euo pipefail
    if ! find "{{folder}}" -name '*.nss' 2>/dev/null | grep -q .; then
        echo "no scripts under {{folder}}"
        exit 0
    fi
    root=()
    if [ -n "{{nwn_root}}" ]; then root=(--root "{{nwn_root}}"); fi
    nwn_script_comp "${root[@]}" -y -R -c "{{folder}}"
