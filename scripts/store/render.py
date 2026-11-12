#!/usr/bin/env python3
"""Renders the App Store screenshots and artwork from design/store/store.html with headless Chrome.

    scripts/store/render.py            everything
    scripts/store/render.py --only iphone-6.9

Inputs: design/store/source (scripts/store/clean_art.swift) and design/store/screens (scripts/store/prep_screens.swift).
Outputs: AppStore/screenshots/en-US/<folder>/01..09.png, in the folders and sizes scripts/appstore_metadata.py
uploads (portrait), and design/store/header-5244x2950.png, search-3840x2560.png, retention-3840x2160.png.
Each shot is its own Chrome window onto the one panorama, so the pairs 1-2 and 4-5 meet exactly at their edge.
Chrome writes RGB PNGs with no alpha channel; the check below fails if one ever has alpha or the wrong size.
"""

import argparse
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PAGE = ROOT / "design/store/store.html"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
# Folder -> portrait size, as scripts/appstore_metadata.py SCREENSHOT_TYPES / SCREENSHOT_SIZES expect.
SHOTS = {"iphone-6.9": (1320, 2868), "iphone-6.3": (1206, 2622), "ipad-13": (2064, 2752)}
ART = {"header": (5244, 2950), "search": (3840, 2560), "retention": (3840, 2160)}


def png_info(path):
    """(width, height, has_alpha) from the PNG header."""
    head = path.read_bytes()[:26]
    width, height = struct.unpack(">II", head[16:24])
    return width, height, head[25] in (4, 6)


def chrome(url, size, out, tmp):
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                    "--allow-file-access-from-files", "--virtual-time-budget=8000", f"--user-data-dir={tmp}/chrome",
                    f"--window-size={size[0]},{size[1]}", f"--screenshot={out}", url], check=True, capture_output=True)
    w, h, alpha = png_info(out)
    if (w, h) != size or alpha:
        sys.exit(f"{out}: {w}x{h}{' with alpha' if alpha else ''}, want {size[0]}x{size[1]} RGB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="one folder (iphone-6.9, iphone-6.3, ipad-13) or artwork name")
    only = ap.parse_args().only
    with tempfile.TemporaryDirectory() as tmp:
        for folder, (w, h) in SHOTS.items():
            if only and only != folder:
                continue
            out = ROOT / "AppStore/screenshots/en-US" / folder
            out.mkdir(parents=True, exist_ok=True)
            for shot in range(1, 10):
                chrome(f"{PAGE.as_uri()}?w={w}&h={h}&shot={shot}", (w, h), out / f"{shot:02d}.png", tmp)
            print(f"{folder}: 9 shots, {w}x{h}")
        for name, (w, h) in ART.items():
            if only and only != name:
                continue
            dest = ROOT / f"design/store/{name}-{w}x{h}.png"
            chrome(f"{PAGE.as_uri()}?w={w}&h={h}&art={name}", (w, h), dest, tmp)
            print(f"{dest.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
