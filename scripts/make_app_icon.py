#!/usr/bin/env python3
"""Draw the app icon: an ink game cover with a vermilion spine, on paper.
Original artwork, no third-party imagery. Needs owner sign-off before submission.

Writes a 1024x1024 RGB PNG with no alpha, the single size the asset catalog needs.

    scripts/make_app_icon.py
"""

import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "Sources/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
SIZE = 1024
PAPER, INK, VERMILION = (0xF4, 0xEF, 0xE6), (0x1C, 0x1A, 0x17), (0xE4, 0x57, 0x2E)
LEFT, RIGHT, TOP, BOTTOM, SPINE = 262, 762, 179, 845, 110  # the cover, 3:4 like the app's covers
RULE_LEFT, RULE_RIGHT, RULE_TOP, RULE_BOTTOM = 440, 680, 300, 332  # a paper title line


def colour(x, y):
    if not (LEFT <= x < RIGHT and TOP <= y < BOTTOM):
        return PAPER
    if x < LEFT + SPINE:
        return VERMILION
    return PAPER if RULE_LEFT <= x < RULE_RIGHT and RULE_TOP <= y < RULE_BOTTOM else INK


def main():
    # Every edge is axis-aligned on a pixel boundary, so no antialiasing is needed.
    rows = bytearray()
    for y in range(SIZE):
        rows.append(0)
        for x in range(SIZE):
            rows += bytes(colour(x, y))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(b"\x89PNG\r\n\x1a\n"
                    + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
                    + chunk(b"IDAT", zlib.compress(bytes(rows), 9))
                    + chunk(b"IEND", b""))
    print(OUT)


if __name__ == "__main__":
    main()
