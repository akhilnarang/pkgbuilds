#!/usr/bin/env bash
# List packages in this repo that are installed here at an older version than the repo has.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
for s in */.SRCINFO; do
	p=${s%/.SRCINFO}
	have=$(pacman -Q "$p" 2>/dev/null | cut -d' ' -f2) || continue
	want=$(awk -F' = ' '$1~/pkgver$/{v=$2} $1~/pkgrel$/{r=$2} $1~/epoch$/{e=$2":"} END{print e v "-" r}' "$s")
	[ "$(vercmp "$have" "$want")" -lt 0 ] && printf '%-30s %s -> %s\n' "$p" "$have" "$want"
done
exit 0
