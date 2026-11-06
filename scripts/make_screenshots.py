#!/usr/bin/env python3
"""Scale reference shots to 1320x2868 RGB PNGs for the iphone-6.9 slot.

Source images are iPhone screenshots (typically 1206x2622 RGBA). App Store Connect
wants 1320x2868 (or 1290x2796) with no alpha. Uses sips, then flattens alpha.

    scripts/make_screenshots.py
"""

import struct
import subprocess
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "maniac-emu-reference-images"
DST = ROOT / "AppStore" / "screenshots" / "en-US" / "iphone-6.9"
W, H = 1320, 2868


def read_rgba(path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"{path.name}: not a png")
    i, width, height, color, raw = 8, 0, 0, 0, b""
    while i < len(data):
        n = int.from_bytes(data[i:i + 4], "big")
        kind = data[i + 4:i + 8]
        chunk = data[i + 8:i + 8 + n]
        if kind == b"IHDR":
            width, height = struct.unpack(">II", chunk[:8])
            color = chunk[9]
        elif kind == b"IDAT":
            raw += chunk
        elif kind == b"IEND":
            break
        i += 12 + n
    if color != 6:
        raise SystemExit(f"{path.name}: expected RGBA, color type {color}")
    rows = zlib.decompress(raw)
    stride = width * 4
    out = bytearray(width * height * 4)
    src = 0
    prev = bytearray(stride)
    for y in range(height):
        filt = rows[src]
        src += 1
        row = bytearray(rows[src:src + stride])
        src += stride
        def left(x):
            return row[x - 4] if x >= 4 else 0
        if filt == 1:  # Sub
            for x in range(stride):
                row[x] = (row[x] + left(x)) & 255
        elif filt == 2:  # Up
            for x in range(stride):
                row[x] = (row[x] + prev[x]) & 255
        elif filt == 3:  # Average
            for x in range(stride):
                row[x] = (row[x] + ((left(x) + prev[x]) // 2)) & 255
        elif filt == 4:  # Paeth
            for x in range(stride):
                a, b = left(x), prev[x]
                c = prev[x - 4] if x >= 4 else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                row[x] = (row[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        elif filt != 0:
            raise SystemExit(f"{path.name}: filter {filt} not handled")
        out[y * stride:(y + 1) * stride] = row
        prev = row
    return width, height, out


def write_rgb(path, width, height, rgba):
    """Flatten onto black and write a color-type-2 PNG."""
    stride = width * 3
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        base = y * width * 4
        for x in range(width):
            r, g, b, a = rgba[base + x * 4:base + x * 4 + 4]
            raw += bytes((r * a // 255, g * a // 255, b * a // 255))
    comp = zlib.compress(bytes(raw), 9)

    def chunk(kind, payload):
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", comp) + chunk(b"IEND", b""))


def main():
    DST.mkdir(parents=True, exist_ok=True)
    sources = sorted(SRC.glob("*.PNG")) + sorted(SRC.glob("*.png"))
    if len(sources) < 3:
        raise SystemExit(f"need at least 3 source images in {SRC}")
    for i, src in enumerate(sources[:10], 1):
        tmp = DST / f".tmp-{i}.png"
        out = DST / f"{i:02d}.png"
        subprocess.run(["sips", "-z", str(H), str(W), "-s", "format", "png", str(src), "--out", str(tmp)],
                       check=True, stdout=subprocess.DEVNULL)
        width, height, rgba = read_rgba(tmp)
        if (width, height) != (W, H):
            raise SystemExit(f"{src.name}: sips produced {width}x{height}")
        write_rgb(out, width, height, rgba)
        tmp.unlink()
        print(out.name, W, H)
    print("ok", min(len(sources), 10))


if __name__ == "__main__":
    sys.exit(main() or 0)
