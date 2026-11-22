#!/usr/bin/env bash
# Pull this repo, then rebuild and install every package that is installed here
# at an older version than the repo has.
#
#   ./update-all.sh           # outdated packages only
#   ./update-all.sh --devel   # also rebuild installed VCS packages (-git etc.)
#   ./update-all.sh spotify   # rebuild these regardless of version
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

devel=; forced=()
for a in "$@"; do
	if [ "$a" = --devel ]; then devel=1; else forced+=("${a%/}"); fi
done

git pull --ff-only

# Keep sources, build trees and built packages out of the git checkout.
cache=${XDG_CACHE_HOME:-$HOME/.cache}/pkgbuilds
mkdir -p "$cache"/{src,build,pkg}
export SRCDEST=$cache/src BUILDDIR=$cache/build PKGDEST=$cache/pkg

todo=("${forced[@]}")
if [ ${#forced[@]} -eq 0 ]; then
	for s in */.SRCINFO; do
		p=${s%/.SRCINFO}
		have=$(pacman -Q "$p" 2>/dev/null | cut -d' ' -f2) || continue
		want=$(awk -F' = ' '$1~/pkgver$/{v=$2} $1~/pkgrel$/{r=$2} $1~/epoch$/{e=$2":"} END{print e v "-" r}' "$s")
		if [ "$(vercmp "$have" "$want")" -lt 0 ]; then
			printf '%-28s %s -> %s\n' "$p" "$have" "$want"; todo+=("$p")
		elif [ -n "$devel" ] && [[ $p =~ -(git|svn|hg|bzr)$ ]]; then
			printf '%-28s %s (VCS rebuild)\n' "$p" "$have"; todo+=("$p")
		fi
	done
fi

if [ ${#todo[@]} -eq 0 ]; then echo "Everything is up to date."; exit 0; fi

failed=()
for p in "${todo[@]}"; do
	echo; echo "==> $p"
	if [ ! -f "$p/PKGBUILD" ]; then echo "no such package: $p" >&2; failed+=("$p"); continue; fi
	(cd "$p" && makepkg -sirc --needed --noconfirm) || failed+=("$p")
	# makepkg rewrites pkgver in a VCS PKGBUILD; keep the checkout clean for the next pull.
	if [[ $p =~ -(git|svn|hg|bzr)$ ]]; then git checkout -q -- "$p/PKGBUILD"; fi
done

echo
if [ ${#failed[@]} -gt 0 ]; then echo "Failed: ${failed[*]}" >&2; exit 1; fi
echo "Updated: ${todo[*]}"
