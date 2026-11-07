#!/usr/bin/env python3
"""Draw the placeholder app icon: four white dots in a diamond on the brand gradient.
Original artwork, no third-party imagery.

Writes a 1024x1024 RGB PNG with no alpha, the single size the asset catalog needs.

    scripts/make_placeholder_icon.py
"""

import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "Sources/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
SIZE = 1024
TOP, BOTTOM = (255, 77, 107), (140, 92, 255)  # AppTheme.brandGradient
CENTER, SPREAD, RADIUS = 512, 205, 118
DOTS = ((CENTER, CENTER - SPREAD), (CENTER + SPREAD, CENTER), (CENTER, CENTER + SPREAD), (CENTER - SPREAD, CENTER))


def in_mark(x, y):
    return any((x - dx) ** 2 + (y - dy) ** 2 <= RADIUS ** 2 for dx, dy in DOTS)


def coverage(x, y):
    corners = ((x + 0.25, y + 0.25), (x + 0.75, y + 0.25), (x + 0.25, y + 0.75), (x + 0.75, y + 0.75))
    return sum(in_mark(*corner) for corner in corners) / 4


def main():
    rows = bytearray()
    for y in range(SIZE):
        rows.append(0)
        for x in range(SIZE):
            t = (x + y) / (2 * SIZE - 2)
            alpha = coverage(x, y)
            rows += bytes(round((a + (b - a) * t) * (1 - alpha) + 255 * alpha) for a, b in zip(TOP, BOTTOM))

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
