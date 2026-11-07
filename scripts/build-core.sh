#!/usr/bin/env bash
# Builds emulator cores into build/cores/<Framework>.xcframework: dynamic, arm64 only, for simulator and
# device, exporting only the bridge getter. A core that fails the no-JIT gate or the export check is
# refused and no xcframework is written. Needs Xcode and the core's submodule, nothing else.
#
#   scripts/build-core.sh [core-id ...]     no arguments: every core in Cores/
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
min_ios=17.0

# xargs runs this script again per source file. Run from the core's directory, so sources.txt and the
# include paths in core.env stay relative to it.
if [ "${1:-}" = --compile-one ]; then
    source=$2 object="$COMPILE_OUT/obj/$2.o" tool=clang flags=$CORE_CFLAGS
    case "$source" in *.cpp | *.cc) tool=clang++ flags=$CORE_CXXFLAGS ;; esac
    # Words after the path on a sources.txt line are flags for that file only, searched before the core's own
    # (Cores/ppsspp, whose upstream builds each library with its own includes and defines).
    shift 2
    mkdir -p "$(dirname "$object")"
    # shellcheck disable=SC2086 # the flag strings are word lists.
    exec xcrun --sdk "$COMPILE_SDK" "$tool" -target "$COMPILE_TARGET" -isysroot "$COMPILE_SYSROOT" -g \
        -I"$root/Sources/Bridge" -DGAGA_CORE_VERSION="\"$COMPILE_VERSION\"" \
        "$@" $flags -c "$source" -o "$object"
fi

build_slice() { # core dir sdk target
    local core=$1 dir=$2 sdk=$3 target=$4
    local out="$root/build/cores/$core/$sdk"
    local framework="$out/$CORE_FRAMEWORK.framework" binary="$out/$CORE_FRAMEWORK.framework/$CORE_FRAMEWORK"
    local sysroot source link_driver=clang objects=() link_extra=()
    sysroot=$(xcrun --sdk "$sdk" --show-sdk-path)
    # A layer-path core links the one shared MoltenVK.framework, which the app embeds once (docs/06 section
    # 2.5). Linking libMoltenVK.a into each core put two copies of MoltenVK's classes in the process.
    if [ "${CORE_USES_MOLTENVK:-}" = 1 ]; then
        link_driver=clang++
        link_extra=(-F "$root/build/moltenvk/dynamic/$sdk" -framework MoltenVK -Wl,-rpath,@loader_path/..
            -framework Foundation -framework Metal -framework QuartzCore -framework UIKit)
    fi
    rm -rf "$out"
    mkdir -p "$framework"

    (
        cd "$dir"
        export COMPILE_OUT="$out" COMPILE_SDK="$sdk" COMPILE_TARGET="$target" COMPILE_SYSROOT="$sysroot" \
            COMPILE_VERSION="$CORE_VERSION ${UPSTREAM_COMMIT:0:8}" CORE_CFLAGS CORE_CXXFLAGS
        xargs -L 1 -P "$(sysctl -n hw.ncpu)" "$root/scripts/build-core.sh" --compile-one <sources.txt
    )

    while read -r source _; do
        objects+=("$out/obj/$source.o")
        case "$source" in *.cpp | *.cc) link_driver=clang++ ;; esac
    done <"$dir/sources.txt"

    # Optional: a Rust part of the core, a static library linked with the bridge sources (Cores/jgenesis).
    # --locked builds exactly what Cargo.lock pins; after the first fetch it needs no network.
    if [ -n "${CORE_CARGO_MANIFEST:-}" ]; then
        local rust_target=aarch64-apple-ios
        [ "$sdk" = iphonesimulator ] && rust_target=aarch64-apple-ios-sim
        IPHONEOS_DEPLOYMENT_TARGET=$min_ios cargo build --quiet --release --locked --target "$rust_target" \
            --manifest-path "$cargo_dir/$CORE_CARGO_MANIFEST" --target-dir "$root/build/cores/$core/cargo"
        objects+=("$root/build/cores/$core/cargo/$rust_target/release/$CORE_CARGO_LIB")
    fi

    # -x keeps local symbols out of the binary. They stay available in the dSYM.
    xcrun --sdk "$sdk" "$link_driver" -dynamiclib -target "$target" -isysroot "$sysroot" \
        -install_name "@rpath/$CORE_FRAMEWORK.framework/$CORE_FRAMEWORK" \
        -compatibility_version 1 -current_version 1 \
        -Wl,-exported_symbols_list,"$dir/$CORE_FRAMEWORK.exports" -Wl,-dead_strip -Wl,-x \
        -o "$binary" "${objects[@]}" ${link_extra[@]+"${link_extra[@]}"} ${CORE_LDFLAGS:-}
    xcrun dsymutil "$binary" -o "$out/$CORE_FRAMEWORK.framework.dSYM"

    # A bundle ID takes letters, digits, hyphens and dots only, so "_" in a core ID becomes "-", and the short
    # version string only digits and dots.
    cat >"$framework/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>$CORE_FRAMEWORK</string>
    <key>CFBundleIdentifier</key><string>com.zenithblue.gagaemu.${core//_/-}</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>$CORE_FRAMEWORK</string>
    <key>CFBundlePackageType</key><string>FMWK</string>
    <key>CFBundleShortVersionString</key><string>${CORE_VERSION//[^0-9.]/}</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>MinimumOSVersion</key><string>$min_ios</string>
</dict>
</plist>
PLIST

    # Only the bridge getter may be visible (docs/06 section 2.5).
    local exports found
    exports=$(nm -gU "$binary" | awk '{print $3}')
    if [ "$exports" != "$CORE_EXPORT" ]; then
        echo "$CORE_FRAMEWORK ($sdk) exports more than $CORE_EXPORT:" >&2
        echo "$exports" >&2
        exit 1
    fi
    echo "exports ($sdk): $exports"

    if found=$(nm -u "$binary" | grep -E "$FORBIDDEN_IMPORTS"); then
        echo "$CORE_FRAMEWORK ($sdk) imports a disabled feature's API: $found" >&2
        exit 1
    fi
    "$root/scripts/nojit-gate.sh" "$binary" "$FORBIDDEN_STRINGS"
    # No boot ROM or other firmware in any core (docs/03 section 5), including a file upstream embeds.
    python3 -I "$root/scripts/bootrom-gate.py" "$binary" "$dir"

    # Optional: source paths that must never be compiled, such as a dynarec's. The dSYM names every compiled
    # file, including any a source file includes, so this checks what was built, not what sources.txt says.
    if [ -n "${FORBIDDEN_SOURCES:-}" ]; then
        if found=$(strings -a "$out/$CORE_FRAMEWORK.framework.dSYM/Contents/Resources/DWARF/$CORE_FRAMEWORK" | grep -E "$FORBIDDEN_SOURCES"); then
            echo "$CORE_FRAMEWORK ($sdk) compiled a forbidden source: $(head -n 3 <<<"$found")" >&2
            exit 1
        fi
        echo "forbidden sources ($sdk): none"
    fi
    # The debug info keeps every name and source file the stripped binary drops, so this proves which
    # files were compiled, not only what the binary still says.
    if [ -n "${FORBIDDEN_DEBUG_STRINGS:-}" ]; then
        "$root/scripts/nojit-gate.sh" "$out/$CORE_FRAMEWORK.framework.dSYM/Contents/Resources/DWARF/$CORE_FRAMEWORK" "$FORBIDDEN_DEBUG_STRINGS"
    fi
}

build_core() {
    local core=$1 dir="$root/Cores/$1"
    [ -f "$dir/core.env" ] || { echo "unknown core: $core" >&2; exit 2; }
    # Optional, so one core's value must not reach the next.
    unset FORBIDDEN_SOURCES FORBIDDEN_DEBUG_STRINGS CORE_CARGO_MANIFEST CORE_CARGO_LIB CORE_USES_MOLTENVK CORE_LDFLAGS SOURCE_AUDIT_REVIEWED
    unset CORE_UPSTREAM_SUBMODULES CORE_BLANK_FILES
    # shellcheck source=/dev/null
    source "$dir/core.env"

    local commit hits
    # An empty UPSTREAM_COMMIT is a core written in this repository, such as the vktest debug core.
    if [ -n "$UPSTREAM_COMMIT" ]; then
        if [ ! -e "$dir/upstream/.git" ]; then
            echo "Missing source. Run: git submodule update --init Cores/$core/upstream" >&2
            exit 1
        fi
        commit=$(git -C "$dir/upstream" rev-parse HEAD)
        if [ "$commit" != "$UPSTREAM_COMMIT" ]; then
            echo "Cores/$core/upstream is at $commit, but core.env pins $UPSTREAM_COMMIT" >&2
            exit 1
        fi
    fi
    [ "${CORE_USES_MOLTENVK:-}" != 1 ] || "$root/scripts/build-moltenvk.sh"
    # Dependencies a core vendors in Cores/<id>/deps are pinned by the commit this repository records.
    if hits=$(git -C "$root" submodule status -- "Cores/$core" | grep -v '^ '); then
        echo "Cores/$core has submodules missing or not at the recorded commit. Run: git submodule update --init Cores/$core" >&2
        echo "$hits" >&2
        exit 1
    fi
    # Optional: upstream's own submodules that the core compiles, pinned by the commits upstream records.
    # shellcheck disable=SC2086 # a list of paths.
    if [ -n "${CORE_UPSTREAM_SUBMODULES:-}" ] &&
        hits=$(git -C "$dir/upstream" submodule status -- $CORE_UPSTREAM_SUBMODULES | grep -v '^ '); then
        echo "Cores/$core/upstream has submodules missing or not at upstream's commit. Run: git -C Cores/$core/upstream submodule update --init $CORE_UPSTREAM_SUBMODULES" >&2
        echo "$hits" >&2
        exit 1
    fi

    # Source audit, docs/04 section 8. A hit needs a read and a per-core decision, not a silent build. The
    # decision is SOURCE_AUDIT_REVIEWED in core.env: file:line: prefixes, so a new pin's moved lines fail again.
    # Status is not used: xargs fails whenever one of its grep batches finds nothing, even if another found a hit.
    hits=$(cd "$dir" && cut -d ' ' -f 1 sources.txt | xargs grep -nE 'PROT_EXEC|MAP_JIT|vm_protect|mach_vm_remap|__clear_cache|sys_icache_invalidate|pthread_jit' || true)
    hits=$(printf '%s\n' "$hits" | grep -vE "${SOURCE_AUDIT_REVIEWED:-^\$}" | grep -v '^$' || true)
    if [ -n "$hits" ]; then
        echo "Source audit found code-generation calls in Cores/$core:" >&2
        echo "$hits" >&2
        exit 1
    fi

    # Optional: upstream files a cargo core must not compile in, such as a boot ROM upstream embeds. Cargo then
    # builds a copy of shim/ and upstream/ in which each listed file is zeros of the same size; the submodule
    # itself is never changed. build_slice reads cargo_dir.
    local cargo_dir=$dir file size
    if [ -n "${CORE_BLANK_FILES:-}" ]; then
        cargo_dir="$root/build/cores/$core/stage"
        rm -rf "$cargo_dir"
        mkdir -p "$cargo_dir"
        cp -R "$dir/shim" "$dir/upstream" "$cargo_dir/"
        for file in $CORE_BLANK_FILES; do
            [ -f "$cargo_dir/upstream/$file" ] || { echo "CORE_BLANK_FILES: Cores/$core/upstream/$file not found" >&2; exit 1; }
            size=$(wc -c <"$cargo_dir/upstream/$file")
            head -c "$size" /dev/zero >"$cargo_dir/upstream/$file"
        done
    fi

    build_slice "$core" "$dir" iphonesimulator "arm64-apple-ios$min_ios-simulator"
    build_slice "$core" "$dir" iphoneos "arm64-apple-ios$min_ios"

    local output="$root/build/cores/$CORE_FRAMEWORK.xcframework"
    rm -rf "$output"
    xcodebuild -create-xcframework -output "$output" \
        -framework "$root/build/cores/$core/iphonesimulator/$CORE_FRAMEWORK.framework" \
        -debug-symbols "$root/build/cores/$core/iphonesimulator/$CORE_FRAMEWORK.framework.dSYM" \
        -framework "$root/build/cores/$core/iphoneos/$CORE_FRAMEWORK.framework" \
        -debug-symbols "$root/build/cores/$core/iphoneos/$CORE_FRAMEWORK.framework.dSYM" >/dev/null
    echo "$core: $output"
}

cores=("$@")
if [ $# -eq 0 ]; then
    cores=()
    for env in "$root"/Cores/*/core.env; do
        cores+=("$(basename "$(dirname "$env")")")
    done
fi
for core in "${cores[@]}"; do
    build_core "$core"
done
