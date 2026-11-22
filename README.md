# pkgbuilds

Personal forks of the AUR packages I use. Nothing is built or installed from the AUR directly;
upstream changes arrive as pull requests and get reviewed before they are merged.

## Layout

One directory per package, holding the AUR repo's files plus `.aur-commit`, the AUR commit the
fork was last synced to.

## Updating

`.github/workflows/aur-sync.yml` runs daily. For every package whose AUR repo has moved past
`.aur-commit`, it opens (or refreshes) a pull request on branch `aur/<pkg>` containing the
upstream diff. Local edits are kept: the change is applied as a 3-way patch, and a conflict
fails the run for that package instead of overwriting anything.

After merging:

```sh
git pull
scripts/outdated.sh          # what is installed here at an older version
cd <pkg> && makepkg -si
```

## Scripts

- `scripts/add.sh <pkg>...` imports packages from the AUR at their current commit.
- `scripts/sync-aur.sh [pkg...]` is what the workflow runs; `DRY_RUN=1` only prints.
- `scripts/outdated.sh` compares installed versions against this repo.
