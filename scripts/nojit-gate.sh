#!/usr/bin/env bash
# No-JIT gate (docs/04 section 8). A non-zero exit fails the build. iOS itself denies JIT (W^X and no
# public entitlement); this gate catches a core that would depend on it, before it crashes on a device.
#
#   nojit-gate.sh <binary or object> [strings-regex] [extra-forbidden-imports] [allowed-imports]   one core binary
#   nojit-gate.sh --entitlements <plist>                         refuses JIT entitlement keys
#   nojit-gate.sh --app <App.app> <entitlements plist>           Xcode build step: everything in a built app,
#                                                                plus the boot ROM gate on each embedded framework
#   nojit-gate.sh --release-set "<core ids>"                     refuses a release set with a non-commercial core
#   nojit-gate.sh --release-app <App.app>                        refuses an app that embeds a non-commercial core
#   nojit-gate.sh --release-ipa <App.ipa>                        unzips an exported IPA: signed entitlements (no
#                                                                get-task-allow, no JIT key), release cores, imports
#   nojit-gate.sh --archive-set "<core ids>"                     release set that is inside GAGA_RELEASE_SET
#   nojit-gate.sh --default-release-set                          prints the default GAGA_RELEASE_SET
#   nojit-gate.sh --sideload-app <App.app>                       refuses a sideload app that links StoreKit
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
default_strings='asmjit::JitRuntime'
# Same list as S3/scripts/ios/build-core.sh:46.
code_gen_imports='_pthread_jit_write_protect_np|_pthread_jit_write_with_callback_np|_sys_icache_invalidate|_sys_dcache_flush|___clear_cache|_mach_vm_protect|_vm_protect$|_mach_vm_remap|_vm_remap$'
# get-task-allow is in the source plist's refusal list: Xcode adds it when it signs a development build, never the plist.
jit_entitlements='allow-jit|allow-unsigned-executable-memory|disable-executable-page-protection|dynamic-codesigning|get-task-allow'

# Third and fourth arguments: the core's FORBIDDEN_IMPORTS (extra refused imports) and ALLOWED_IMPORTS (reviewed
# exceptions to code_gen_imports, a regex per core in its core.env, with the reason beside it).
check_binary() {
    local binary=$1 strings_regex=${2:-$default_strings} extra=${3:-} allowed=${4:-} imports contents found
    # A file the tools cannot read must fail, not pass with nothing found.
    if ! imports=$(nm -u "$binary") || ! contents=$(strings -a "$binary"); then
        echo "no-JIT gate: cannot read $binary" >&2
        return 1
    fi
    found=$(grep -E "$code_gen_imports${extra:+|$extra}" <<<"$imports" || true)
    [ -z "$allowed" ] || found=$(grep -vE "$allowed" <<<"$found" || true)
    if [ -n "$found" ]; then
        echo "no-JIT gate: $binary imports a code-generation or refused API: $found" >&2
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

# A core.env variable of the core that builds framework $1 (empty if unset). A framework without a core.env is
# not a core: XCTest ships in test builds, and anything else gets the default lists.
core_var() {
    local env
    for env in "$root"/Cores/*/core.env; do
        if grep -qx "CORE_FRAMEWORK=$1" "$env"; then
            # shellcheck source=/dev/null
            (source "$env" && eval "echo \"\${$2:-}\"")
            return
        fi
    done
}

# One embedded core: its strings, plus the same FORBIDDEN_IMPORTS as build-core.sh, so a stale framework in
# DerivedData cannot skip them.
check_core_binary() {
    check_binary "$2" "$(core_var "$1" FORBIDDEN_STRINGS)" "$(core_var "$1" FORBIDDEN_IMPORTS)" "$(core_var "$1" ALLOWED_IMPORTS)"
}

# Entitlements of the signed product (codesign), not the source plist. An unsigned app has none to read.
# $2 = strict: also refuse get-task-allow (a distribution build never has it) and refuse an unsigned app.
check_signed_entitlements() {
    local ents flat
    if ! ents=$(codesign -d --entitlements :- "$1" 2>/dev/null); then
        [ "${2:-}" != strict ] || { echo "release gate: $1 is not signed" >&2; return 1; }
        echo "release gate: $(basename "$1") is unsigned, signed entitlements not checked"
        return 0
    fi
    flat=$(tr -d ' \n\t' <<<"$ents")
    if grep -oE 'allow-jit|allow-unsigned-executable-memory|disable-executable-page-protection|dynamic-codesigning' <<<"$flat"; then
        echo "release gate: $1 is signed with a JIT entitlement" >&2
        return 1
    fi
    if [ "${2:-}" = strict ] && grep -q 'get-task-allow</key><true/>' <<<"$flat"; then
        echo "release gate: $1 is signed with get-task-allow, a development build" >&2
        return 1
    fi
    echo "release gate: pass signed entitlements of $(basename "$1")"
}

# Legal gate for non-commercial licences (docs/03 section 5): snes9x, Genesis Plus GX, PicoDrive and FBNeo
# forbid commercial use, and GagaEmu is a paid app, so they never enter an App Store or TestFlight build.
noncommercial_framework() { # framework name -> core id, or nothing
    local env
    # Named here too, so a dropped CORE_NONCOMMERCIAL=1 or a stale framework with no core.env still fails.
    case "$1" in
        Snes9xCore) echo snes9x; return ;;
        GenesisPlusGXCore) echo genesis_plus_gx; return ;;
        PicodriveCore) echo picodrive; return ;;
        FbneoCore) echo fbneo; return ;;
    esac
    flagged_framework "$1" CORE_NONCOMMERCIAL
}

# Framework name and a core.env flag -> the core id when that core sets the flag to 1, or nothing.
flagged_framework() {
    local env
    for env in "$root"/Cores/*/core.env; do
        if grep -qx "CORE_FRAMEWORK=$1" "$env" && grep -qx "$2=1" "$env"; then
            basename "$(dirname "$env")"
            return
        fi
    done
}

# A release core set: an explicit list, never the sideload profile, the debug core or a non-commercial core.
check_release_set() {
    local core
    [ -n "$1" ] || { echo "release gate: the release core set is empty" >&2; return 1; }
    for core in $1; do
        case "$core" in
            sideload) echo "release gate: GAGA_CORE_SET=sideload is for free personal builds, never a release" >&2; return 1 ;;
            vktest) echo "release gate: GAGA_CORE_SET must not include vktest in a release" >&2; return 1 ;;
            snes9x | genesis_plus_gx | picodrive | fbneo)
                echo "release gate: $core has a non-commercial licence and must not be in a release core set" >&2; return 1 ;;
        esac
        if grep -qx 'CORE_NONCOMMERCIAL=1' "$root/Cores/$core/core.env" 2>/dev/null; then
            echo "release gate: $core has a non-commercial licence and must not be in a release core set" >&2
            return 1
        fi
        if grep -qx 'CORE_RELEASE_HOLD=1' "$root/Cores/$core/core.env" 2>/dev/null; then
            echo "release gate: $core sets CORE_RELEASE_HOLD=1 (see its core.env) and must not be in a release core set" >&2
            return 1
        fi
    done
    echo "release gate: pass $1"
}

# The cores cleared for an App Store or TestFlight build (owner decision 2026-11-08, docs/03 section 5): every
# core in Cores/ except the non-commercial ones, those with CORE_RELEASE_HOLD=1 and the vktest debug core.
# GPL cores are in it.
default_release_set() {
    local env core set=''
    for env in "$root"/Cores/*/core.env; do
        core=$(basename "$(dirname "$env")")
        [ "$core" != vktest ] || continue
        grep -qxE 'CORE_(NONCOMMERCIAL|RELEASE_HOLD)=1' "$env" || set+="${set:+ }$core"
    done
    echo "$set"
}

# An archive's core set: a valid release set that stays inside the cores cleared for release (GAGA_RELEASE_SET,
# default default_release_set). Run by the app build step on any Release archive, Organizer ones included.
check_archive_set() {
    local core release=${GAGA_RELEASE_SET:-$(default_release_set)}
    check_release_set "$1" || return 1
    for core in $1; do
        if [[ " $release " != *" $core "* ]]; then
            echo "release gate: $core is outside the release set ($release). Regenerate with GAGA_CORE_SET=\"$release\"." >&2
            return 1
        fi
    done
}
# An exported IPA: unzip it, then check the signed app the way a store build must be.
check_release_ipa() {
    local tmp app rc=0
    tmp=$(mktemp -d)
    unzip -q "$1" -d "$tmp" || { rm -rf "$tmp"; echo "release gate: cannot unzip $1" >&2; return 1; }
    app=$(ls -d "$tmp"/Payload/*.app 2>/dev/null | head -n 1)
    if [ -z "$app" ]; then
        echo "release gate: $1 has no Payload/*.app" >&2
        rc=1
    else
        check_ipa_app "$app" || rc=1
    fi
    rm -rf "$tmp"
    return $rc
}

# `|| return 1` on each line: inside a `||` caller, set -e is off and only the last status would count.
check_ipa_app() {
    local framework name
    check_signed_entitlements "$1" strict || return 1
    check_release_app "$1" || return 1
    check_binary "$1/$(basename "$1" .app)" || return 1
    for framework in "$1"/Frameworks/*.framework; do
        [ -d "$framework" ] || continue
        name=$(basename "$framework" .framework)
        check_core_binary "$name" "$framework/$name" || return 1
    done
}

# A built release app (an archive's): no non-commercial core framework and no debug core inside it.
check_release_app() {
    local framework core
    for framework in "$1"/Frameworks/*.framework; do
        [ -d "$framework" ] || continue
        if [ "$(basename "$framework")" = VkTestCore.framework ]; then
            echo "release gate: $1 embeds vktest, a debug and test core" >&2
            return 1
        fi
        core=$(noncommercial_framework "$(basename "$framework" .framework)")
        if [ -n "$core" ]; then
            echo "release gate: $1 embeds $core, which has a non-commercial licence" >&2
            return 1
        fi
        core=$(flagged_framework "$(basename "$framework" .framework)" CORE_RELEASE_HOLD)
        if [ -n "$core" ]; then
            echo "release gate: $1 embeds $core, which sets CORE_RELEASE_HOLD=1 (see its core.env)" >&2
            return 1
        fi
    done
    check_signed_entitlements "$1"
    echo "release gate: pass $(basename "$1")"
}

# A sideload app sells nothing (docs/03 section 5): its code links no StoreKit library and imports no StoreKit
# symbol, so no purchase call can be reached. Covers the app, its debug dylib and any test bundle inside it.
check_sideload_app() {
    local binary imports links found=''
    for binary in "$1/$(basename "$1" .app)" "$1/$(basename "$1" .app).debug.dylib" "$1"/PlugIns/*.xctest/*; do
        [ -f "$binary" ] && [ -x "$binary" ] || continue
        if ! links=$(otool -L "$binary") || ! imports=$(nm -u "$binary"); then
            echo "sideload gate: cannot read $binary" >&2
            return 1
        fi
        # The StoreKit libraries, Swift symbols of the StoreKit module (mangled "8StoreKit"), and SK classes and
        # functions. GagaEmu's own StoreKitManager (mangled "15StoreKitManager") is not StoreKit.
        found+=$( { grep -E 'StoreKit' <<<"$links"; grep -E '(^|[^0-9])8StoreKit|_StoreKit_SwiftUI|_OBJC_CLASS_\$_SK|^_SK' <<<"$imports"; } |
            sed "s|^|$(basename "$binary"): |" || true)
    done
    if [ -n "$found" ]; then
        echo "sideload gate: $1 links StoreKit, but a sideload build must sell nothing:" >&2
        head -n 5 <<<"$found" >&2
        return 1
    fi
    echo "sideload gate: pass $(basename "$1"), no StoreKit"
}

check_app() {
    local app=$1 framework name binary env core links contents
    check_entitlements "$2"
    # GAGA_SIDELOAD is a build setting from scripts/generate-project.sh for GAGA_CORE_SET=sideload.
    [ "${GAGA_SIDELOAD:-}" != 1 ] || check_sideload_app "$app"
    # Xcode passes build settings to this step. GAGA_RELEASE=1 comes from scripts/appstore_release.sh, and a
    # build that can sell (PAYWALL_ENABLED) is commercial, so neither may carry a non-commercial core.
    if [ "${GAGA_RELEASE:-}" = 1 ] || [[ " ${SWIFT_ACTIVE_COMPILATION_CONDITIONS:-} " == *" PAYWALL_ENABLED "* ]]; then
        check_release_app "$app"
    fi
    # Any Release archive, Organizer's too (Xcode sets ACTION=install), must use the release core set.
    if [ "${ACTION:-}" = install ] && [ "${CONFIGURATION:-}" = Release ] && [ "${GAGA_SIDELOAD:-}" != 1 ]; then
        check_archive_set "${GAGA_CORE_SET:-}"
        check_release_app "$app"
    fi
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
        check_core_binary "$name" "$framework/$name"
        # A stale core framework in DerivedData skips build-core.sh's own boot ROM check (docs/07, JGenesis 32X).
        python3 -I "$root/scripts/bootrom-gate.py" "$framework/$name"
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
    --release-set) check_release_set "${2:-}" ;;
    --release-app) check_release_app "${2:?usage: nojit-gate.sh --release-app <App.app>}" ;;
    --release-ipa) check_release_ipa "${2:?usage: nojit-gate.sh --release-ipa <App.ipa>}" ;;
    --archive-set) check_archive_set "${2:-}" ;;
    --default-release-set) default_release_set ;;
    --sideload-app) check_sideload_app "${2:?usage: nojit-gate.sh --sideload-app <App.app>}" ;;
    "") echo "usage: nojit-gate.sh <binary> [strings-regex]" >&2; exit 2 ;;
    *) check_binary "$1" "${2:-$default_strings}" "${3:-}" "${4:-}" ;;
esac
