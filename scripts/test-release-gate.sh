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
mkdir -p "$tmp/scripts" "$tmp/Cores/free" "$tmp/Cores/nc" "$tmp/Cores/vktest" "$tmp/Free.app/Frameworks/FreeCore.framework" \
    "$tmp/Mixed.app/Frameworks/FreeCore.framework" "$tmp/Mixed.app/Frameworks/NcCore.framework" \
    "$tmp/Debug.app/Frameworks/VkTestCore.framework" "$tmp/Snes.app/Frameworks/Snes9xCore.framework"
cp "$root/scripts/nojit-gate.sh" "$tmp/scripts/"
printf 'CORE_FRAMEWORK=FreeCore\n' >"$tmp/Cores/free/core.env"
printf 'CORE_FRAMEWORK=NcCore\nCORE_NONCOMMERCIAL=1\n' >"$tmp/Cores/nc/core.env"
printf 'CORE_FRAMEWORK=VkTestCore\n' >"$tmp/Cores/vktest/core.env"
mkdir -p "$tmp/Cores/held" "$tmp/Held.app/Frameworks/HeldCore.framework"
printf 'CORE_FRAMEWORK=HeldCore\nCORE_RELEASE_HOLD=1\n' >"$tmp/Cores/held/core.env"

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
expect fail --release-app "$tmp/Debug.app"
expect fail --release-app "$tmp/Snes.app" # named non-commercial framework, no core.env flag
expect fail --release-set "snes9x"
expect fail --release-set "free held"
expect fail --release-app "$tmp/Held.app"

# Default release set: every core except the non-commercial ones, held ones and vktest.
unset GAGA_RELEASE_SET
got=$("$tmp/scripts/nojit-gate.sh" --default-release-set)
if [ "$got" != free ]; then
    echo "FAIL: --default-release-set gave '$got', expected 'free'" >&2
    failures=$((failures + 1))
fi
expect pass --archive-set "free"
expect fail --archive-set "free nc"
expect fail --archive-set "free vktest"

export GAGA_RELEASE_SET=free
expect pass --archive-set "free"
expect fail --archive-set ""
expect fail --archive-set "free nc"
expect fail --archive-set "free vktest"
expect fail --archive-set "free other" # a core outside the release set

# Banned imports, from tiny objects built here. Empty strings argument = the default list.
fx="$tmp/fx"
mkdir -p "$fx"
cc() { xcrun clang -arch arm64 "$@"; }
printf 'int main(void){return 0;}\n' >"$fx/clean.c"
printf 'void pthread_jit_write_protect_np(int);\nint main(void){pthread_jit_write_protect_np(0);return 0;}\n' >"$fx/jit.c"
printf 'void sys_dcache_flush(void*,unsigned long);\nint main(void){sys_dcache_flush(0,0);return 0;}\n' >"$fx/dcache.c"
printf 'int vm_remap();\nint main(void){return vm_remap();}\n' >"$fx/remap.c"
printf 'void *dlopen(const char*,int);\nint main(void){return dlopen("x",0)!=0;}\n' >"$fx/dlopen.c"
for name in clean jit dcache remap dlopen; do cc -c "$fx/$name.c" -o "$fx/$name.o"; done
expect pass "$fx/clean.o"
expect fail "$fx/jit.o"
expect fail "$fx/dcache.o"
expect fail "$fx/remap.o"
expect pass "$fx/remap.o" asmjit::JitRuntime '' '(^|[[:space:]])_vm_remap$' # a reviewed per-core exception
expect pass "$fx/dlopen.o"
expect fail "$fx/dlopen.o" asmjit::JitRuntime '_dlopen$' # a core.env FORBIDDEN_IMPORTS

# JIT and get-task-allow entitlements, in the source plist and in a signed product.
plist() { printf '<?xml version="1.0"?>\n<plist version="1.0"><dict>\n%s\n</dict></plist>\n' "$2" >"$1"; }
plist "$fx/good.plist" '<key>com.apple.developer.game-center</key><true/>'
plist "$fx/jit.plist" '<key>com.apple.security.cs.allow-jit</key><true/>'
plist "$fx/gta.plist" '<key>get-task-allow</key><true/>'
expect pass --entitlements "$fx/good.plist"
expect fail --entitlements "$fx/jit.plist"
expect fail --entitlements "$fx/gta.plist"

ipa() { # name, entitlements plist -> $fx/<name>.ipa with a signed Free.app
    local app="$fx/$1/Payload/Free.app"
    mkdir -p "$app/Frameworks/FreeCore.framework"
    cc "$fx/clean.c" -o "$app/Free"
    cc -dynamiclib "$fx/clean.c" -o "$app/Frameworks/FreeCore.framework/FreeCore" 2>/dev/null ||
        cc "$fx/clean.c" -o "$app/Frameworks/FreeCore.framework/FreeCore"
    plist "$app/Info.plist" '<key>CFBundleExecutable</key><string>Free</string><key>CFBundleIdentifier</key><string>test.free</string>'
    codesign -s - -f --entitlements "$2" "$app" 2>/dev/null
    (cd "$fx/$1" && zip -qr "$fx/$1.ipa" Payload)
}
ipa good "$fx/good.plist"
ipa gta "$fx/gta.plist"
ipa jit "$fx/jit.plist"
expect pass --release-ipa "$fx/good.ipa"
expect fail --release-ipa "$fx/gta.ipa"
expect fail --release-ipa "$fx/jit.ipa"
expect fail --release-ipa "$fx/missing.ipa"

for core in $noncommercial; do
    env="$root/Cores/$core/core.env"
    if [ -f "$env" ] && ! grep -qx 'CORE_NONCOMMERCIAL=1' "$env"; then
        echo "FAIL: $env lacks CORE_NONCOMMERCIAL=1" >&2
        failures=$((failures + 1))
    fi
done

if ! python3 "$root/scripts/check_store_assets.py" >/dev/null; then
    echo "FAIL: scripts/check_store_assets.py" >&2
    failures=$((failures + 1))
fi

[ "$failures" -eq 0 ] || exit 1
echo "release gate tests: pass"
