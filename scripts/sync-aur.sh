#!/usr/bin/env bash
# Open (or refresh) one pull request per package whose AUR repo has moved past
# the commit pinned in <pkg>/.aur-commit. The upstream change is applied as a
# 3-way patch, so local edits to a fork are kept; a conflict fails that package.
#
#   scripts/sync-aur.sh            # all packages
#   scripts/sync-aur.sh byobu wrk  # only these
#   DRY_RUN=1 scripts/sync-aur.sh  # show what would change, touch nothing remote
set -euo pipefail
MIRROR=https://github.com/archlinux/aur.git
BASE=${BASE_BRANCH:-main}
DRY_RUN=${DRY_RUN:-}
cd "$(git rev-parse --show-toplevel)"

if [ $# -gt 0 ]; then pkgs=("$@"); else
	mapfile -t pkgs < <(find . -mindepth 2 -maxdepth 2 -name .aur-commit -printf '%h\n' | sed 's|^\./||' | sort)
fi

refs=(); for p in "${pkgs[@]}"; do refs+=("refs/heads/$p"); done
declare -A head
while read -r sha ref; do head[${ref#refs/heads/}]=$sha; done < <(git ls-remote "$MIRROR" "${refs[@]}")

ver() { # version from a .SRCINFO at a given commit:path
	git show "$1" 2>/dev/null | awk -F' = ' '$1~/pkgver$/{v=$2} $1~/pkgrel$/{r=$2} $1~/epoch$/{e=$2":"} END{print e v "-" r}'
}

[ -n "$DRY_RUN" ] || git fetch -q origin
start=$(git rev-parse --abbrev-ref HEAD)
rc=0
for p in "${pkgs[@]}"; do
	old=$(<"$p/.aur-commit"); new=${head[$p]:-}
	if [ -z "$new" ]; then echo "::warning::$p: no longer on the AUR mirror"; continue; fi
	[ "$old" = "$new" ] && continue

	git fetch -q "$MIRROR" "refs/heads/$p"
	oldver=$(ver "$old:.SRCINFO"); newver=$(ver "$new:.SRCINFO")
	title="$p: $oldver -> $newver"
	log=$(git log --format='- `%h` %s (%an, %cs)' "$old..$new")
	echo "== $title"; echo "$log"
	if [ -n "$DRY_RUN" ]; then git diff --stat "$old" "$new"; continue; fi

	branch="aur/$p"
	if [ "$(git show "origin/$branch:$p/.aur-commit" 2>/dev/null)" = "$new" ]; then
		echo "   PR branch already up to date"; continue
	fi
	git checkout -q -B "$branch" "origin/$BASE"
	if ! git diff --binary "$old" "$new" | git apply --3way --index --directory="$p"; then
		echo "::error::$p: upstream change conflicts with local edits; merge AUR ${new:0:7} by hand"
		git reset -q --hard; rc=1; continue
	fi
	echo "$new" > "$p/.aur-commit"; git add -f "$p/.aur-commit"
	git commit -q -m "$title" -m "AUR ${old:0:7}..${new:0:7}"
	git push -q -f origin "$branch"

	body=$(printf 'AUR changes for `%s` (`%s`..`%s`):\n\n%s\n\nUpstream history: https://aur.archlinux.org/cgit/aur.git/log/?h=%s\n' \
		"$p" "${old:0:7}" "${new:0:7}" "$log" "$p")
	if num=$(gh pr list --head "$branch" --state open --json number -q '.[0].number') && [ -n "$num" ]; then
		gh pr edit "$num" --title "$title" --body "$body" >/dev/null
		echo "   updated PR #$num"
	else
		gh pr create --base "$BASE" --head "$branch" --title "$title" --body "$body"
	fi
done
[ -n "$DRY_RUN" ] || git checkout -q "$start"
exit $rc
