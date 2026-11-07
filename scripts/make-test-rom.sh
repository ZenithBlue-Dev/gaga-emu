#!/usr/bin/env bash
# Writes a homebrew test ROM from Sources/Debug to a file, for import tests. The extension picks which:
# .gba (GBATestROM), .gb or .gbc (GBTestROM).
# Usage: scripts/make-test-rom.sh <output.gba|output.gb|output.gbc>
set -euo pipefail
output=${1:?usage: make-test-rom.sh <output.gba|output.gb|output.gbc>}
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cat >"$work/main.swift" <<'SWIFT'
import Foundation
let url = URL(fileURLWithPath: CommandLine.arguments[1])
switch url.pathExtension {
case "gb": try GBTestROM.build().write(to: url)
case "gbc": try GBTestROM.build(color: true).write(to: url)
default: try GBATestROM.build().write(to: url)
}
SWIFT
xcrun --sdk macosx swiftc -D DEBUG "$work/main.swift" "$root/Sources/Debug/GBATestROM.swift" "$root/Sources/Debug/GBTestROM.swift" -o "$work/make-rom"
"$work/make-rom" "$output"
echo "$output"
