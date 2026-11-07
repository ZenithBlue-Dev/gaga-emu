#!/usr/bin/env bash
# Writes a homebrew test ROM from Sources/Debug to a file, for import tests. The extension picks which:
# .gba (GBATestROM), .gb or .gbc (GBTestROM), .nes (NESTestROM, with battery RAM), .sfc (SNESTestROM), .nds
# (NDSTestROM), .md (MDTestROM, with battery SRAM), .exe (PS1TestEXE), .cue (PS1TestEXE.disc, which also writes the
# .bin beside it), .gagavk (VkTestROM, for the layer-path test core), .com (DOSTestCOM), or .zip (GridleeTestSet, a MAME
# ROM set: MAME runs it only from a file named gridlee.zip).
# Usage: scripts/make-test-rom.sh <output.gba|output.gb|output.gbc|output.nes|output.sfc|output.nds|output.md|output.exe|output.cue|output.gagavk|output.com|gridlee.zip>
set -euo pipefail
output=${1:?usage: make-test-rom.sh <output.gba|output.gb|output.gbc|output.nes|output.sfc|output.nds|output.md|output.exe|output.cue|output.gagavk|output.com|gridlee.zip>}
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
case "zip": try GridleeTestSet.build().write(to: url)
default: try GBATestROM.build().write(to: url)
}
SWIFT
xcrun --sdk macosx swiftc -D DEBUG "$work/main.swift" "$root/Sources/Debug/ARMAssembler.swift" "$root/Sources/Debug/GBATestROM.swift" \
    "$root/Sources/Debug/GBTestROM.swift" "$root/Sources/Debug/NESTestROM.swift" "$root/Sources/Debug/SNESTestROM.swift" \
    "$root/Sources/Debug/NDSTestROM.swift" "$root/Sources/Debug/MDTestROM.swift" "$root/Sources/Debug/PS1TestEXE.swift" \
    "$root/Sources/Debug/VkTestROM.swift" "$root/Sources/Debug/DOSTestCOM.swift" "$root/Sources/Debug/GridleeTestSet.swift" \
    "$root/Sources/Hub/RomPatcher.swift" -o "$work/make-rom"
"$work/make-rom" "$output"
echo "$output"
