#!/usr/bin/env bash
# Writes a homebrew test ROM from Sources/Debug to a file, for import tests. The extension picks which:
# .gba (GBATestROM), .gb or .gbc (GBTestROM), .exe (PS1TestEXE), or .cue (PS1TestEXE.disc, which also
# writes the .bin beside it).
# Usage: scripts/make-test-rom.sh <output.gba|output.gb|output.gbc|output.exe|output.cue>
set -euo pipefail
output=${1:?usage: make-test-rom.sh <output.gba|output.gb|output.gbc|output.exe|output.cue>}
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cat >"$work/main.swift" <<'SWIFT'
import Foundation
let url = URL(fileURLWithPath: CommandLine.arguments[1])
switch url.pathExtension {
case "gb": try GBTestROM.build().write(to: url)
case "gbc": try GBTestROM.build(color: true).write(to: url)
case "exe": try PS1TestEXE.build().write(to: url)
case "cue":
    let disc = PS1TestEXE.disc()
    let bin = url.deletingPathExtension().appendingPathExtension("bin")
    try disc.bin.write(to: bin)
    try Data(disc.cue(bin.lastPathComponent).utf8).write(to: url)
default: try GBATestROM.build().write(to: url)
}
SWIFT
xcrun --sdk macosx swiftc -D DEBUG "$work/main.swift" "$root/Sources/Debug/GBATestROM.swift" "$root/Sources/Debug/GBTestROM.swift" \
    "$root/Sources/Debug/PS1TestEXE.swift" -o "$work/make-rom"
"$work/make-rom" "$output"
echo "$output"
