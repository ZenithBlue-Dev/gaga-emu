#!/usr/bin/env python3
"""Boot ROM gate. A non-zero exit fails the build. GagaEmu ships no BIOS, boot ROM or other console firmware
(docs/03 section 5), so no core binary may hold one, even when upstream embeds it (docs/07, the JGenesis 32X
incident).

  bootrom-gate.py <binary> [<core dir>]   refuses a binary that holds a ROM in bootrom-hashes.txt, or the
                                          first 64 bytes of any *.bin or *.rom that the core's sources pull
                                          in with include_bytes! or incbin
  bootrom-gate.py --add <rom> <name>      prints a bootrom-hashes.txt line; the ROM itself never enters the repo
  bootrom-gate.py --self-test             checks the scanner on generated data

bootrom-hashes.txt keeps hashes only: the SHA-1 and size of the whole ROM, the SHA-1 of its first 32 bytes,
and the CRC-32 of each 16-byte window of those 32 bytes. Any copy of the first 32 bytes covers one 16-byte
block at a 16-byte boundary of the binary, so the scan hashes only those blocks and confirms with the SHA-1.
"""
import hashlib
import os
import random
import re
import subprocess
import sys
import tempfile
import zlib

LIST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bootrom-hashes.txt")
BLOCK = 16
PREFIX = 32
SOURCE_SUFFIXES = (".rs", ".c", ".cc", ".cpp", ".cxx", ".h", ".hpp", ".inc", ".s", ".S", ".asm", ".m", ".mm")
EMBED = re.compile(rb'(?:include_bytes!\s*\(\s*|incbin\s+\\?)"([^"\\]+\.(?:bin|rom))\\?"', re.I)


def entry(data, name):
    head = data[:PREFIX]
    crcs = ",".join("%08x" % zlib.crc32(head[k:k + BLOCK]) for k in range(len(head) - BLOCK + 1))
    return f"{hashlib.sha1(data).hexdigest()} {len(data)} {hashlib.sha1(head).hexdigest()} {crcs} {name}"


def load(path=LIST):
    roms = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                sha, size, head_sha, crcs, name = line.split(" ", 4)
                roms.append((sha, int(size), head_sha, [int(c, 16) for c in crcs.split(",")], name))
    return roms


def known_hits(data, roms):
    table = {}
    for rom in roms:
        for k, crc in enumerate(rom[3]):
            table.setdefault(crc, []).append((rom, k))
    view, crc32, hits = memoryview(data), zlib.crc32, {}
    for pos in range(0, len(data) - BLOCK + 1, BLOCK):
        for rom, k in table.get(crc32(view[pos:pos + BLOCK]), ()):
            start = pos - k
            if start >= 0 and hashlib.sha1(view[start:start + PREFIX]).digest().hex() == rom[2]:
                whole = hashlib.sha1(view[start:start + rom[1]]).hexdigest() == rom[0]
                hits[(rom[4], start)] = "the whole ROM" if whole else "its first 32 bytes"
    return [f"{name} at offset {start:#x} ({what})" for (name, start), what in sorted(hits.items())]


def embedded_files(core_dir):
    """(source file, embedded file) for each *.bin or *.rom that a source under core_dir embeds."""
    found = subprocess.run(["grep", "-rlIE", "include_bytes!|incbin", core_dir], capture_output=True)
    if found.returncode > 1:
        sys.exit(f"boot ROM gate: cannot search {core_dir}: {found.stderr.decode().strip()}")
    pairs = []
    for source in found.stdout.decode().splitlines():
        if not source.endswith(SOURCE_SUFFIXES) or "/.git/" in source:
            continue
        with open(source, "rb") as f:
            for rel in EMBED.findall(f.read()):
                rel = rel.decode()
                # include_bytes! is relative to the source file; incbin to the compiler's directory (the core's).
                for base in (os.path.dirname(source), core_dir):
                    path = os.path.normpath(os.path.join(base, rel))
                    if os.path.isfile(path):
                        pairs.append((source, path))
                        break
    return pairs


def embedded_hits(data, core_dir):
    hits = []
    for source, path in embedded_files(core_dir):
        with open(path, "rb") as f:
            head = f.read(64)
        # A blank or one-byte-filled file matches any padding, and holds no firmware.
        if len(set(head)) > 1 and head in data:
            hits.append(f"{os.path.relpath(path, core_dir)} (embedded by {os.path.relpath(source, core_dir)})")
    return hits


def check(binary, core_dir=None):
    try:
        with open(binary, "rb") as f:
            data = f.read()
    except OSError as error:
        print(f"boot ROM gate: cannot read {binary}: {error}", file=sys.stderr)
        return 1
    hits = known_hits(data, load())
    if core_dir:
        hits += embedded_hits(data, core_dir)
    if hits:
        print(f"boot ROM gate: {binary} holds firmware GagaEmu must not ship:", file=sys.stderr)
        for hit in hits:
            print(f"  {hit}", file=sys.stderr)
        return 1
    print(f"boot ROM gate: pass {os.path.basename(binary)}")
    return 0


def self_test():
    rng = random.Random(1)
    rom = bytes(rng.randrange(256) for _ in range(2048))
    with tempfile.TemporaryDirectory() as tmp:
        hashes = os.path.join(tmp, "hashes.txt")
        with open(hashes, "w") as f:
            f.write("# test\n" + entry(rom, "test ROM") + "\n")
        roms = load(hashes)
        filler = bytes(rng.randrange(256) for _ in range(5000))
        for offset in (0, 1, 15, 16, 17, 31, 4999):
            assert known_hits(filler[:offset] + rom + filler, roms), offset
            assert known_hits(filler[:offset] + rom[:32] + filler, roms), offset
        assert not known_hits(filler + rom[:31] + filler, roms)
        assert not known_hits(filler, roms)
        os.makedirs(os.path.join(tmp, "core", "src"))
        with open(os.path.join(tmp, "core", "src", "rom.bin"), "wb") as f:
            f.write(rom[:100])
        with open(os.path.join(tmp, "core", "src", "lib.rs"), "w") as f:
            f.write('const R: &[u8] = include_bytes!("rom.bin");\n')
        with open(os.path.join(tmp, "core", "asm.c"), "w") as f:
            f.write('__asm__(".incbin \\"src/rom.bin\\"");\n')
        core = os.path.join(tmp, "core")
        assert len(embedded_files(core)) == 2, embedded_files(core)
        assert embedded_hits(filler + rom[:64] + filler, core)
        assert not embedded_hits(filler, core)
    print("boot ROM gate self-test: pass")
    return 0


if __name__ == "__main__":
    args = sys.argv[1:]
    if args == ["--self-test"]:
        sys.exit(self_test())
    if len(args) == 3 and args[0] == "--add":
        with open(args[1], "rb") as f:
            print(entry(f.read(), args[2]))
        sys.exit(0)
    if len(args) in (1, 2) and not args[0].startswith("-"):
        sys.exit(check(*args))
    sys.exit(__doc__)
