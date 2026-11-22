#!/usr/bin/env bash
# Import AUR packages into this repo: scripts/add.sh <pkg>...
# Copies the package's current AUR files into <pkg>/ and pins the AUR commit in <pkg>/.aur-commit.
set -euo pipefail
MIRROR=https://github.com/archlinux/aur.git
cd "$(git rev-parse --show-toplevel)"

for p in "$@"; do
	if [ -e "$p" ]; then echo "$p: already present, skipping" >&2; continue; fi
	if ! git fetch -q "$MIRROR" "refs/heads/$p" 2>/dev/null; then
		echo "$p: not found on the AUR mirror" >&2; continue
	fi
	sha=$(git rev-parse FETCH_HEAD)
	mkdir "$p"
	git archive "$sha" | tar -x -C "$p"
	echo "$sha" > "$p/.aur-commit"
	git add -f "$p"
	echo "$p: imported at ${sha:0:7}"
done
