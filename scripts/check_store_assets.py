#!/usr/bin/env python3
"""Fails if the App Store screenshot pipeline names or holds a Manic EMU asset (docs/BRAND.md, Legal rules).

Checks the text of the pipeline files and every file name under the pipeline folders. Exits non-zero on a hit.

    scripts/check_store_assets.py
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATTERN = re.compile(r"mani(a)?c|reference[-_ ]images", re.I)
# The pipeline: the composer, its inputs, the upload script and the upload folders.
TEXT = ["scripts/make_screenshots.swift", "scripts/appstore_metadata.py", "design/store/captions.json"]
FOLDERS = ["design/store", "AppStore/screenshots", "build/store"]
# The old script read the Manic reference folder; it must not come back.
GONE = ["scripts/make_screenshots.py"]


def problems(root):
    found = [f"{p}: must not exist" for p in GONE if (root / p).exists()]
    for rel in TEXT:
        path = root / rel
        if path.exists():
            for n, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
                if PATTERN.search(line):
                    found.append(f"{rel}:{n}: {line.strip()[:120]}")
    for rel in FOLDERS:
        for path in (root / rel).rglob("*") if (root / rel).exists() else []:
            if PATTERN.search(str(path.relative_to(root))):
                found.append(f"{path.relative_to(root)}: Manic asset path")
    return found


def self_test():
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        t = Path(tmp)
        (t / "design/store/captures").mkdir(parents=True)
        (t / "scripts").mkdir()
        (t / "scripts/make_screenshots.swift").write_text('let src = "design/store/captures"\n')
        assert problems(t) == [], problems(t)
        (t / "design/store/captures/manic-01.png").write_bytes(b"")
        (t / "scripts/make_screenshots.swift").write_text('let src = "maniac-emu-reference-images"\n')
        assert len(problems(t)) == 2, problems(t)


if __name__ == "__main__":
    self_test()
    hits = problems(ROOT)
    for hit in hits:
        print(hit, file=sys.stderr)
    print("ok" if not hits else f"{len(hits)} Manic asset reference(s) in the screenshot pipeline")
    sys.exit(1 if hits else 0)
