#!/usr/bin/env python3
"""Download the remote sources listed in .SRCINFO files and check their checksums.

    scripts/verify-sources.py <path/to/.SRCINFO>...

Only reads the .SRCINFO; nothing from the package is executed. Generic and
x86_64 sources are checked. Prints one line per source: OK, MISMATCH, NOSUM
(checksum is SKIP or absent), SKIPPED (local file or VCS source) or ERROR.
Exits 1 on any MISMATCH.
"""
import hashlib
import re
import sys
import urllib.request

ALGOS = ["b2", "sha512", "sha384", "sha256", "sha224", "sha1", "md5"]
MAX_BYTES = 2 * 1024**3


def parse(path):
    fields = {}
    for line in open(path, encoding="utf-8", errors="replace"):
        m = re.match(r"\s*(\S+) = (.*)$", line.rstrip("\n"))
        if m:
            fields.setdefault(m.group(1), []).append(m.group(2))
    return fields


def digest(url, algo):
    h = hashlib.blake2b() if algo == "b2" else hashlib.new(algo)
    req = urllib.request.Request(url, headers={"User-Agent": "curl/8"})
    total = 0
    with urllib.request.urlopen(req, timeout=120) as r:
        while chunk := r.read(1 << 20):
            total += len(chunk)
            if total > MAX_BYTES:
                raise RuntimeError("larger than 2 GiB")
            h.update(chunk)
    return h.hexdigest(), total


def main():
    bad = False
    for path in sys.argv[1:]:
        f = parse(path)
        for suffix in ("", "_x86_64"):
            sources = f.get("source" + suffix, [])
            algo = next((a for a in ALGOS if f.get(f"{a}sums{suffix}")), None)
            sums = f.get(f"{algo}sums{suffix}", []) if algo else []
            for i, src in enumerate(sources):
                url = src.split("::", 1)[-1]
                want = sums[i] if i < len(sums) else None
                if not re.match(r"https?://", url):
                    print(f"SKIPPED  {url}  (local file or VCS source)")
                elif want in (None, "SKIP"):
                    print(f"NOSUM    {url}")
                else:
                    try:
                        got, size = digest(url, algo)
                    except Exception as e:  # noqa: BLE001
                        print(f"ERROR    {url}  ({e})")
                        continue
                    if got == want:
                        print(f"OK       {url}  ({algo}, {size} bytes)")
                    else:
                        bad = True
                        print(f"MISMATCH {url}  ({algo}: expected {want}, got {got})")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
