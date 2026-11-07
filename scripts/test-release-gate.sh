#!/usr/bin/env bash
# Checks the non-commercial release gate in scripts/nojit-gate.sh (docs/03 section 5) on a throwaway tree,
# and that every core with a non-commercial licence is flagged in its core.env. Exits non-zero on a failure.
#
#   scripts/test-release-gate.sh
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
# Licences that forbid commercial use. A core here without CORE_NONCOMMERCIAL=1 would reach a release.
noncommercial='snes9x genesis_plus_gx picodrive fbneo'

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/scripts" "$tmp/Cores/free" "$tmp/Cores/nc" "$tmp/Free.app/Frameworks/FreeCore.framework" \
    "$tmp/Mixed.app/Frameworks/FreeCore.framework" "$tmp/Mixed.app/Frameworks/NcCore.framework"
cp "$root/scripts/nojit-gate.sh" "$tmp/scripts/"
printf 'CORE_FRAMEWORK=FreeCore\n' >"$tmp/Cores/free/core.env"
printf 'CORE_FRAMEWORK=NcCore\nCORE_NONCOMMERCIAL=1\n' >"$tmp/Cores/nc/core.env"

failures=0
expect() { # pass|fail, then the gate's arguments
    local want=$1
    shift
    if "$tmp/scripts/nojit-gate.sh" "$@" >/dev/null 2>&1; then got=pass; else got=fail; fi
    if [ "$got" != "$want" ]; then
        echo "FAIL: nojit-gate.sh $* gave $got, expected $want" >&2
        failures=$((failures + 1))
    fi
}

expect pass --release-set "free"
expect fail --release-set "free nc"
expect fail --release-set "sideload"
expect fail --release-set "vktest"
expect fail --release-set ""
expect pass --release-app "$tmp/Free.app"
expect fail --release-app "$tmp/Mixed.app"

for core in $noncommercial; do
    env="$root/Cores/$core/core.env"
    if [ -f "$env" ] && ! grep -qx 'CORE_NONCOMMERCIAL=1' "$env"; then
        echo "FAIL: $env lacks CORE_NONCOMMERCIAL=1" >&2
        failures=$((failures + 1))
    fi
done

[ "$failures" -eq 0 ] || exit 1
echo "release gate tests: pass"
