# pkgbuilds

Personal forks of the AUR packages I use. Nothing is built or installed from the AUR directly;
upstream changes arrive as pull requests and get reviewed before they are merged.

The PKGBUILDs and accompanying files in each package directory come from the AUR and belong to
their respective maintainers; see each package's AUR page for authorship and licence.

## Layout

One directory per package, holding the AUR repo's files plus `.aur-commit`, the AUR commit the
fork was last synced to.

## Updating

`.github/workflows/aur-sync.yml` runs daily. For every package whose AUR repo has moved past
`.aur-commit`, it opens (or refreshes) a pull request on branch `aur/<pkg>` containing the
upstream diff. Local edits are kept: the change is applied as a 3-way patch, and a conflict
fails the run for that package instead of overwriting anything.

Each pull request is reviewed automatically by `.github/workflows/review.yml`: a script labels it
`trivial-bump` (only version and checksums changed) or `needs-review`, and Claude reads the diff
and comments with a verdict. Nothing is approved or merged automatically. The Claude step needs
the `CLAUDE_CODE_OAUTH_TOKEN` secret (from `claude setup-token`) and is skipped without it.

After merging:

```sh
./update-all.sh              # pull, then rebuild and install whatever is outdated here
./update-all.sh --devel      # also rebuild installed VCS (-git) packages
./update-all.sh spotify      # rebuild named packages regardless of version
```

Sources, build trees and built packages go to `~/.cache/pkgbuilds`, not into the checkout.

## Scripts

- `update-all.sh` updates the installed packages on this machine from the repo.
- `scripts/add.sh <pkg>...` imports packages from the AUR at their current commit.
- `scripts/sync-aur.sh [pkg...]` is what the workflow runs; `DRY_RUN=1` only prints.
- `scripts/outdated.sh` compares installed versions against this repo.
- `scripts/classify-change.py <base> <head>` says whether a change is only a version bump.
- `scripts/verify-sources.py <.SRCINFO>...` downloads the listed sources and checks their checksums.
