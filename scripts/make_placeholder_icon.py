#!/usr/bin/env python3
"""Draw the placeholder app icon: a white "G" on the brand gradient. Original artwork, no third-party imagery.

Writes a 1024x1024 RGB PNG with no alpha, the single size the asset catalog needs.

    scripts/make_placeholder_icon.py
"""

import math
import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "Sources/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
SIZE = 1024
TOP, BOTTOM = (255, 77, 107), (140, 92, 255)  # AppTheme.brandGradient
CX, CY, OUTER, INNER, BAR = 512, 512, 330, 205, 62


def in_g(x, y):
    dx, dy = x - CX, CY - y
    radius = math.hypot(dx, dy)
    if radius > OUTER:
        return False
    if dx >= 10 and abs(dy) <= BAR:  # crossbar
        return True
    if radius < INNER:
        return False
    return not (dy > BAR and 0 < math.degrees(math.atan2(dy, dx)) < 52)  # mouth


def coverage(x, y):
    corners = (in_g(x + 0.25, y + 0.25), in_g(x + 0.75, y + 0.25), in_g(x + 0.25, y + 0.75), in_g(x + 0.75, y + 0.75))
    return sum(corners) / 4


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
