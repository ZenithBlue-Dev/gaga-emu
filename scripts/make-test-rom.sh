#!/usr/bin/env bash
# Writes the homebrew GBA test ROM from Sources/Debug/GBATestROM.swift to a file, for import tests.
# Usage: scripts/make-test-rom.sh <output.gba>
set -euo pipefail
output=${1:?usage: make-test-rom.sh <output.gba>}
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cat >"$work/main.swift" <<'SWIFT'
import Foundation
try GBATestROM.build().write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
SWIFT
xcrun --sdk macosx swiftc -D DEBUG "$work/main.swift" "$root/Sources/Debug/GBATestROM.swift" -o "$work/make-rom"
"$work/make-rom" "$output"
echo "$output"
