#!/usr/bin/env python3
"""Say whether a package update is only a version and checksum bump.

    scripts/classify-change.py <base-ref> <head-ref>

Each changed file is compared with version strings, checksums and pkgrel masked
out. If nothing else differs the change is "trivial"; otherwise it is
"needs-review" and the lines that differ are printed. Exit status is 0 either
way; the verdict is the first line of output.
"""
import difflib
import re
import subprocess
import sys

ALLOWED = {"PKGBUILD", ".SRCINFO", ".aur-commit"}


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout


def show(ref, path):
    r = subprocess.run(["git", "show", f"{ref}:{path}"], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


def version(srcinfo):
    m = re.search(r"^\s*pkgver = (\S+)$", srcinfo or "", re.M)
    return m.group(1) if m else None


def mask(text, ver):
    if ver:
        text = text.replace(ver, "@VER@")
    text = re.sub(r"\b[0-9a-f]{32,128}\b", "@SUM@", text)
    text = re.sub(r"^(\s*pkgrel\s*=\s*)\S+$", r"\1@REL@", text, flags=re.M)
    return text.splitlines()


def main():
    base, head = sys.argv[1:3]
    files = git("diff", "--name-only", f"{base}...{head}").split()
    merge_base = git("merge-base", base, head).strip()
    problems = []
    for path in files:
        pkg, _, name = path.partition("/")
        if name not in ALLOWED:
            problems.append(f"{path}: file outside the usual PKGBUILD/.SRCINFO set changed")
            continue
        if name == ".aur-commit":
            continue
        old, new = show(merge_base, path), show(head, path)
        if old is None or new is None:
            problems.append(f"{path}: file added or removed")
            continue
        oldver = version(show(merge_base, f"{pkg}/.SRCINFO"))
        newver = version(show(head, f"{pkg}/.SRCINFO"))
        a, b = mask(old, oldver), mask(new, newver)
        if a != b:
            diff = [l for l in difflib.unified_diff(a, b, lineterm="", n=0) if not l.startswith(("---", "+++", "@@"))]
            problems.append(f"{path}:\n" + "\n".join("    " + l for l in diff))
    if not files:
        problems.append("no files changed")
    print("needs-review" if problems else "trivial")
    for p in problems:
        print(p)


if __name__ == "__main__":
    main()
