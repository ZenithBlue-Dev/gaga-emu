#!/usr/bin/env python3
"""Writes Resources/cheats.pack from a checkout of libretro-database's cht folder.

    python3 -I scripts/build-cheat-pack.py <libretro-database>/cht

The input is untrusted data: this only reads text from it. Sources/Session/CheatDatabase.swift reads the pack.
Only systems whose core is in the release set and can apply a .cht are packed (docs/cheats-sources.md).

Pack: 4-byte little-endian header length, then the JSON header {platform: [offset, length]} of each system's
xz index, then the payload the offsets count from. An index is JSON {title key: [offset, length, start, count]}:
an xz chunk of the payload, and the bytes of this title's cheats inside it. Chunks keep the pack small, and a
lookup still inflates only one index and one chunk.
"""
import json
import lzma
import pathlib
import re
import struct
import sys
import unicodedata

OUT = pathlib.Path(__file__).resolve().parent.parent / "Resources/cheats.pack"
# Same limits as CheatFormat.swift.
MAX_BYTES, MAX_ENTRIES, MAX_CODE, MAX_NAME = 4 * 1024 * 1024, 20_000, 8 * 1024, 200
CHUNK = 256 * 1024

# Platform IDs from CoreCatalog. Left out: systems whose release-set core has no cheat hook (docs/06), and 3DS, MAME
# and the 32X, whose only core is not in the release set.
SYSTEMS = {
    "gb": ["Nintendo - Game Boy"],
    "gbc": ["Nintendo - Game Boy Color"],
    "gba": ["Nintendo - Game Boy Advance"],
    "nes": ["Nintendo - Nintendo Entertainment System", "Nintendo - Family Computer Disk System"],
    "snes": ["Nintendo - Super Nintendo Entertainment System", "Nintendo - Satellaview"],
    "n64": ["Nintendo - Nintendo 64", "Nintendo - Nintendo 64 (Aleck64)", "Nintendo - Nintendo 64 (iQue)",
            "Nintendo - Nintendo 64 (Unreleased)"],
    "nds": ["Nintendo - Nintendo DS"],
    "ps1": ["Sony - PlayStation"],
    "psp": ["Sony - PlayStation Portable"],
    "saturn": ["Sega - Saturn"],
    "megadrive": ["Sega - Mega Drive - Genesis"],
    "megacd": ["Sega - Mega-CD - Sega CD"],
    "mastersystem": ["Sega - Master System - Mark III"],
    "gamegear": ["Sega - Game Gear"],
    "sg1000": ["Sega - SG-1000"],
    "pce": ["NEC - PC Engine - TurboGrafx 16", "NEC - PC Engine CD - TurboGrafx-CD"],
    "sgx": ["NEC - PC Engine SuperGrafx"],
    "ws": ["Bandai - WonderSwan", "Bandai - WonderSwan Color"],
}
LINE = re.compile(r'^\s*cheat(\d{1,6})_(desc|code)\s*=\s*"?(.*?)"?\s*$')
TAG = re.compile(r"\([^)]*\)|\[[^\]]*\]")
CONTROL = re.compile(r"[\x00-\x1f\x7f]")


def key(title):
    """Must match CheatDatabase.key: no tags, no article, only ASCII letters and digits."""
    text = unicodedata.normalize("NFD", TAG.sub("", title)).lower()
    text = re.sub(r"^\s*the\s+", "", re.sub(r",\s*the\b", " ", text))
    return re.sub(r"[^a-z0-9]", "", text)


def entries(path):
    """(name, code) of each usable cheat in one .cht. RetroArch's memory-search cheats have no code."""
    found = {}
    for line in path.read_bytes().decode("utf-8", "replace").splitlines():
        match = LINE.match(line)
        if match:
            found.setdefault(int(match[1]), {})[match[2]] = CONTROL.sub("", match[3]).strip()
    return [(item.get("desc", ""), item["code"]) for _, item in sorted(found.items())
            if item.get("code") and len(item["code"]) <= MAX_CODE]


def title_text(paths, stats):
    """The title's files as one .cht. A name says which dump and device its code is for, as codes differ by region."""
    lines, count, size = [], 0, 0
    for path in sorted(paths):
        label = ", ".join(tag.strip("()[] ") for tag in TAG.findall(path.stem))
        for name, code in entries(path):
            name = name or f"Cheat {count + 1}"
            name = f"{name[:MAX_NAME - len(label[:40]) - 3]} ({label[:40]})" if label else name[:MAX_NAME]
            text = f'cheat{count}_desc = "{name}"\ncheat{count}_code = "{code}"\n'
            if count + 1 > MAX_ENTRIES or size + len(text.encode()) > MAX_BYTES:
                stats["dropped"] += 1
                continue
            lines.append(text)
            count += 1
            size += len(text.encode())
    return "".join(lines).encode(), count


def xz(data):
    return lzma.compress(data, format=lzma.FORMAT_XZ, check=lzma.CHECK_CRC32, preset=6)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    root = pathlib.Path(sys.argv[1])
    payload, header, stats = bytearray(), {}, {"dropped": 0}
    for platform, folders in SYSTEMS.items():
        titles = {}
        for folder in folders:
            if not (root / folder).is_dir():
                sys.exit(f"build-cheat-pack: {root / folder} is missing")
            for path in (root / folder).glob("*.cht"):
                if path.is_file() and not path.is_symlink() and key(path.stem):
                    titles.setdefault(key(path.stem), []).append(path)
        index, chunk, placed, games, cheats = {}, bytearray(), [], 0, 0

        def flush():
            blob = xz(bytes(chunk))
            for name, start, count in placed:
                index[name] = [len(payload), len(blob), start, count]
            payload.extend(blob)
            chunk.clear()
            placed.clear()

        for name in sorted(titles):
            text, count = title_text(titles[name], stats)
            if not count:
                continue
            placed.append((name, len(chunk), len(text)))
            chunk.extend(text)
            games += 1
            cheats += count
            if len(chunk) >= CHUNK:
                flush()
        if chunk:
            flush()
        blob = xz(json.dumps(index, separators=(",", ":"), sort_keys=True).encode())
        header[platform] = [len(payload), len(blob)]
        payload.extend(blob)
        print(f"{platform}: {games} games, {cheats} cheats")
    head = json.dumps(header, separators=(",", ":")).encode()
    OUT.write_bytes(struct.pack("<I", len(head)) + head + payload)
    print(f"{OUT.stat().st_size} bytes, {stats['dropped']} cheats over the limits dropped")


main()
