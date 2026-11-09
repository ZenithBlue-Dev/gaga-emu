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
    # PrBoom applies Doom cheat words through its own hook.
    "doom": ["PrBoom"],
    # Applied by the host's poke engine (Sources/Bridge/PokeEngine.swift).
    "atari2600": ["Atari - 2600"],
    "atari5200": ["Atari - 5200"],
    "atari7800": ["Atari - 7800"],
    "atari8bit": ["Atari - 8-bit Family"],
    "jaguar": ["Atari - Jaguar"],
    "lynx": ["Atari - Lynx"],
    "vb": ["Nintendo - Virtual Boy"],
    "ngp": ["SNK - Neo Geo Pocket", "SNK - Neo Geo Pocket Color"],
    "dreamcast": ["Sega - Dreamcast"],
}
# Memory the poke engine writes, per platform: (first address of a code, bytes). Must match PokeEngine.base and each
# core's retro_get_memory_size. A code outside it, or one with a ?? placeholder, cannot be applied and is left out.
POKE_MEMORY = {
    "atari2600": (0, 128),
    "atari5200": (0, 65536),
    "atari7800": (0, 65536),
    "atari8bit": (0, 65536),
    "jaguar": (0, 0x200000),
    "lynx": (0, 65536),
    "vb": (0x05000000, 0x10000),
    "ngp": (0, 16384),
    "dreamcast": (0, 0x1000000),
}
LINE = re.compile(r'^\s*cheat(\d{1,6})_(\w+)\s*=\s*"?(.*?)"?\s*$')
POKE_LINE = re.compile(r"([0-9A-Fa-f]{1,16}):([0-9A-Fa-f]{2}|[0-9A-Fa-f]{4}|[0-9A-Fa-f]{8})")
# RetroArch's cheat_type: only "set to value"; 4 to 7 gate the next entry. memory_search_size: 3, 4, 5 are 8, 16, 32 bits.
WIDTHS = {"3": 1, "4": 2, "5": 4}
CONDITIONS = {"4", "5", "6", "7"}
MAX_REPEAT = 64
TAG = re.compile(r"\([^)]*\)|\[[^\]]*\]")
CONTROL = re.compile(r"[\x00-\x1f\x7f]")


def key(title):
    """Must match CheatDatabase.key: no tags, no article, only ASCII letters and digits."""
    text = unicodedata.normalize("NFD", TAG.sub("", title)).lower()
    text = re.sub(r"^\s*the\s+", "", re.sub(r",\s*the\b", " ", text))
    return re.sub(r"[^a-z0-9]", "", text)


def poke_code(item, previous):
    """A RetroArch memory-search cheat as poke lines, or None if the poke engine cannot run it exactly."""
    width = WIDTHS.get(item.get("memory_search_size", ""))
    if (item.get("handler") != "1" or item.get("cheat_type") != "1" or not width or previous in CONDITIONS
            or item.get("big_endian") not in ("false", "no", None)):
        return None
    try:
        address, value = int(item["address"]), int(item["value"])
        repeat = int(item.get("repeat_count") or 1)
        step = int(item.get("repeat_add_to_address") or 1)
        grow = int(item.get("repeat_add_to_value") or 0)
    except (KeyError, ValueError):
        return None
    if grow or not 1 <= repeat <= MAX_REPEAT or not 0 <= value < 1 << (8 * width):
        return None
    return "+".join(f"{address + index * step * width:08X}:{value:0{width * 2}X}" for index in range(repeat))


def fits_memory(code, memory):
    """Every line of a poke code parses and lies inside the core's memory."""
    start, size = memory
    for line in code.split("+"):
        match = POKE_LINE.fullmatch(line.strip())
        if not match or not start <= int(match[1], 16) <= start + size - len(match[2]) // 2:
            return False
    return True


def entries(path, memory=None):
    """(name, code) of each usable cheat in one .cht. RetroArch's memory-search cheats have no code: on a poke
    platform (memory is set) they are converted, otherwise dropped."""
    found = {}
    for line in path.read_bytes().decode("utf-8", "replace").splitlines():
        match = LINE.match(line)
        if match:
            found.setdefault(int(match[1]), {})[match[2]] = CONTROL.sub("", match[3]).strip()
    result, previous = [], None
    for _, item in sorted(found.items()):
        code = item.get("code")
        if memory and not code:
            code = poke_code(item, previous)
        previous = item.get("cheat_type") if item.get("handler") == "1" else None
        if code and len(code) <= MAX_CODE and (not memory or fits_memory(code, memory)):
            result.append((item.get("desc", ""), code))
    return result


def title_text(paths, stats, memory=None):
    """The title's files as one .cht. A name says which dump and device its code is for, as codes differ by region."""
    lines, count, size = [], 0, 0
    for path in sorted(paths):
        label = ", ".join(tag.strip("()[] ") for tag in TAG.findall(path.stem))
        for name, code in entries(path, memory):
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
            text, count = title_text(titles[name], stats, POKE_MEMORY.get(platform))
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
