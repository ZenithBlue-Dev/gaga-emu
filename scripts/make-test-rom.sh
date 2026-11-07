#!/usr/bin/env bash
# Writes a homebrew test ROM from Sources/Debug to a file, for import tests. The extension picks which:
# .gba (GBATestROM), .gb or .gbc (GBTestROM), .nes (NESTestROM, with battery RAM), .sfc (SNESTestROM), .nds
# (NDSTestROM), .md (MDTestROM, with battery SRAM), .exe (PS1TestEXE), .cue (PS1TestEXE.disc, which also writes the
# .bin beside it), .gagavk (VkTestROM, for the layer-path test core), .com (DOSTestCOM), .z64 (N64TestROM, with
# battery SRAM), .elf (PSPTestELF), .zip (GridleeTestSet, a MAME ROM set: MAME runs it only from a file named
# gridlee.zip), .pce or .sgx (PCETestROM, with backup RAM), .vb (VBTestROM, with cartridge RAM), .ngc (NGPTestROM),
# .wsc (WSTestROM) or .min (PMTestROM).
# Backlog cores (group-retro): .sms (SMSTestROM, with cartridge RAM), .a26 (Atari2600TestROM), .a78 (Atari7800TestROM), .lnx (LynxTestROM), .a52 and .xex (Atari800TestROM), .j64 (JaguarTestROM), .crt (C64TestROM), .adf (AmigaTestROM), .wad (DoomTestWAD).
# Usage: scripts/make-test-rom.sh <output.gba|output.gb|output.gbc|output.nes|output.sfc|output.nds|output.md|output.exe|output.cue|output.gagavk|output.com|output.z64|output.elf|gridlee.zip|output.pce|output.sgx|output.vb|output.ngc|output.wsc|output.min|output.sms|output.a26|output.a78|output.lnx|output.a52|output.xex|output.j64|output.crt|output.adf|output.wad>
set -euo pipefail
output=${1:?usage: make-test-rom.sh <output.gba|output.gb|output.gbc|output.nes|output.sfc|output.nds|output.md|output.exe|output.cue|output.gagavk|output.com|output.z64|output.elf|gridlee.zip|output.pce|output.sgx|output.vb|output.ngc|output.wsc|output.min|output.sms|output.a26|output.a78|output.lnx|output.a52|output.xex|output.j64|output.crt|output.adf|output.wad>}
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cat >"$work/main.swift" <<'SWIFT'
import Foundation
let url = URL(fileURLWithPath: CommandLine.arguments[1])
switch url.pathExtension {
case "gb": try GBTestROM.build().write(to: url)
case "gbc": try GBTestROM.build(color: true).write(to: url)
case "nes": try NESTestROM.build().write(to: url)
case "exe": try PS1TestEXE.build().write(to: url)
case "cue":
    let disc = PS1TestEXE.disc()
    let bin = url.deletingPathExtension().appendingPathExtension("bin")
    try disc.bin.write(to: bin)
    try Data(disc.cue(bin.lastPathComponent).utf8).write(to: url)
case "sfc": try SNESTestROM.build().write(to: url)
case "nds": try NDSTestROM.build().write(to: url)
case "md": try MDTestROM.build().write(to: url)
case "gagavk": try VkTestROM.build().write(to: url)
case "com": try DOSTestCOM.build().write(to: url)
case "elf": try PSPTestELF.build().write(to: url)
case "zip": try GridleeTestSet.build().write(to: url)
case "z64": try N64TestROM.build().write(to: url)
case "pce": try PCETestROM.build().write(to: url)
case "sgx": try PCETestROM.build(superGrafx: true).write(to: url)
case "vb": try VBTestROM.build().write(to: url)
case "ngc": try NGPTestROM.build().write(to: url)
case "wsc": try WSTestROM.build().write(to: url)
case "min": try PMTestROM.build().write(to: url)
case "sms": try SMSTestROM.build().write(to: url)
case "a26": try Atari2600TestROM.build().write(to: url)
case "a78": try Atari7800TestROM.build().write(to: url)
case "lnx": try LynxTestROM.build().write(to: url)
case "a52": try Atari800TestROM.a52().write(to: url)
case "xex": try Atari800TestROM.xex().write(to: url)
case "j64": try JaguarTestROM.build().write(to: url)
case "crt": try C64TestROM.crt().write(to: url)
case "adf": try AmigaTestROM.adf().write(to: url)
case "wad": try DoomTestWAD.wad().write(to: url)
default: try GBATestROM.build().write(to: url)
}
SWIFT
xcrun --sdk macosx swiftc -D DEBUG "$work/main.swift" "$root/Sources/Debug/ARMAssembler.swift" "$root/Sources/Debug/GBATestROM.swift" \
    "$root/Sources/Debug/GBTestROM.swift" "$root/Sources/Debug/NESTestROM.swift" "$root/Sources/Debug/SNESTestROM.swift" \
    "$root/Sources/Debug/NDSTestROM.swift" "$root/Sources/Debug/MDTestROM.swift" "$root/Sources/Debug/PS1TestEXE.swift" \
    "$root/Sources/Debug/VkTestROM.swift" "$root/Sources/Debug/DOSTestCOM.swift" "$root/Sources/Debug/GridleeTestSet.swift" \
    "$root/Sources/Debug/N64TestROM.swift" "$root/Sources/Debug/PSPTestELF.swift" "$root/Sources/Debug/PCETestROM.swift" \
    "$root/Sources/Debug/VBTestROM.swift" "$root/Sources/Debug/NGPTestROM.swift" "$root/Sources/Debug/WSTestROM.swift" \
    "$root/Sources/Debug/PMTestROM.swift" "$root/Sources/Debug/SMSTestROM.swift" "$root/Sources/Debug/Atari2600TestROM.swift" \
    "$root/Sources/Debug/Atari7800TestROM.swift" "$root/Sources/Debug/LynxTestROM.swift" "$root/Sources/Debug/Atari800TestROM.swift" \
    "$root/Sources/Debug/JaguarTestROM.swift" "$root/Sources/Debug/C64TestROM.swift" "$root/Sources/Debug/AmigaTestROM.swift" \
    "$root/Sources/Debug/DoomTestWAD.swift" \
    "$root/Sources/Hub/RomPatcher.swift" -o "$work/make-rom"
"$work/make-rom" "$output"
echo "$output"
