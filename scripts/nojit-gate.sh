#!/usr/bin/env bash
# No-JIT gate (docs/04 section 8). A non-zero exit fails the build. iOS itself denies JIT (W^X and no
# public entitlement); this gate catches a core that would depend on it, before it crashes on a device.
#
#   nojit-gate.sh <binary or object> [forbidden-strings-regex]   one core binary
#   nojit-gate.sh --entitlements <plist>                         refuses JIT entitlement keys
#   nojit-gate.sh --app <App.app> <entitlements plist>           Xcode build step: everything in a built app
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
default_strings='asmjit::JitRuntime'
# Same list as S3/scripts/ios/build-core.sh:46.
code_gen_imports='_pthread_jit_write_protect_np|_sys_icache_invalidate|___clear_cache|_mach_vm_protect|_vm_protect$'
jit_entitlements='allow-jit|allow-unsigned-executable-memory|disable-executable-page-protection|dynamic-codesigning'

check_binary() {
    local binary=$1 strings_regex=${2:-$default_strings} imports contents found
    # A file the tools cannot read must fail, not pass with nothing found.
    if ! imports=$(nm -u "$binary") || ! contents=$(strings -a "$binary"); then
        echo "no-JIT gate: cannot read $binary" >&2
        return 1
    fi
    if found=$(grep -E "$code_gen_imports" <<<"$imports"); then
        echo "no-JIT gate: $binary imports a code-generation API: $found" >&2
        return 1
    fi
    if found=$(grep -E "$strings_regex" <<<"$contents"); then
        echo "no-JIT gate: $binary contains a JIT runtime string: $(head -n 3 <<<"$found")" >&2
        return 1
    fi
    echo "no-JIT gate: pass $(basename "$binary")"
}

check_entitlements() {
    local found
    if found=$(grep -E "$jit_entitlements" "$1"); then
        echo "no-JIT gate: $1 asks for a JIT entitlement: $found" >&2
        return 1
    fi
    echo "no-JIT gate: pass $(basename "$1")"
}

# A framework without a core.env is not a core. XCTest ships in test builds, and anything else gets the default list.
strings_for_framework() {
    local env
    for env in "$root"/Cores/*/core.env; do
        if grep -qx "CORE_FRAMEWORK=$1" "$env"; then
            # shellcheck source=/dev/null
            (source "$env" && echo "$FORBIDDEN_STRINGS")
            return
        fi
    done
    echo "$default_strings"
}

check_app() {
    local app=$1 framework name binary env core links contents
    check_entitlements "$2"
    for env in "$root"/Cores/*/core.env; do
        # shellcheck source=/dev/null
        name=$(source "$env" && echo "$CORE_FRAMEWORK")
        core=$(basename "$(dirname "$env")")
        # GAGA_CORE_SET is a build setting from scripts/generate-project.sh. Run by hand, every core is expected.
        if [ -z "${GAGA_CORE_SET:-}" ] || [[ " $GAGA_CORE_SET " == *" $core "* ]]; then
            if [ ! -f "$app/Frameworks/$name.framework/$name" ]; then
                echo "no-JIT gate: $name is not embedded in $app" >&2
                return 1
            fi
        elif [ -e "$app/Frameworks/$name.framework" ]; then
            echo "no-JIT gate: $name is outside GAGA_CORE_SET but embedded in $app. Clean the build folder." >&2
            return 1
        fi
    done
    binary="$app/$(basename "$app" .app)"
    check_binary "$binary"
    [ ! -f "$binary.debug.dylib" ] || check_binary "$binary.debug.dylib"
    local mvk_users=0 mvk_copies=()
    for framework in "$app"/Frameworks/*.framework; do
        [ -d "$framework" ] || continue
        name=$(basename "$framework" .framework)
        case "$name" in XC* | Testing) continue ;; esac
        check_binary "$framework/$name" "$(strings_for_framework "$name")"
        # Read whole, not piped into grep -q: with pipefail an early grep exit fails the pipe and hides a hit.
        links=$(otool -L "$framework/$name") contents=$(strings -a "$framework/$name")
        if grep -q '@rpath/MoltenVK.framework/MoltenVK ' <<<"$links"; then mvk_users=$((mvk_users + 1)); fi
        # A MoltenVK Objective-C class name. Two binaries with it put two copies of each class in the process.
        if grep -qx 'MVKBlockObserver' <<<"$contents"; then mvk_copies+=("$name"); fi
    done
    for binary in "$binary" "$binary.debug.dylib"; do
        if [ -f "$binary" ] && grep -qx 'MVKBlockObserver' <<<"$(strings -a "$binary")"; then mvk_copies+=("$(basename "$binary")"); fi
    done
    check_moltenvk "$app" "$mvk_users" ${mvk_copies[@]+"${mvk_copies[@]}"}
}

# One MoltenVK per process (docs/06 section 2.5): only MoltenVK.framework holds its classes, and it is
# embedded exactly when a core links it.
check_moltenvk() {
    local app=$1 users=$2
    shift 2
    if [ $# -gt 1 ] || { [ $# -eq 1 ] && [ "$1" != MoltenVK ]; }; then
        echo "no-JIT gate: MoltenVK classes are defined in $*. Link MoltenVK.framework instead of libMoltenVK.a." >&2
        return 1
    fi
    if [ "$users" -gt 0 ] && [ ! -f "$app/Frameworks/MoltenVK.framework/MoltenVK" ]; then
        echo "no-JIT gate: a core links MoltenVK.framework, but $app does not embed it" >&2
        return 1
    fi
    if [ "$users" -eq 0 ] && [ -e "$app/Frameworks/MoltenVK.framework" ]; then
        echo "no-JIT gate: MoltenVK.framework is embedded in $app, but no core links it. Clean the build folder." >&2
        return 1
    fi
    echo "no-JIT gate: MoltenVK copies: $#"
}

case "${1:-}" in
    --entitlements) check_entitlements "${2:?usage: nojit-gate.sh --entitlements <plist>}" ;;
    --app) check_app "${2:?usage: nojit-gate.sh --app <App.app> <plist>}" "${3:?usage: nojit-gate.sh --app <App.app> <plist>}" ;;
    "") echo "usage: nojit-gate.sh <binary> [strings-regex]" >&2; exit 2 ;;
    *) check_binary "$1" "${2:-$default_strings}" ;;
esac
