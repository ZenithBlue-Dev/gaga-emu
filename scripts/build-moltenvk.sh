#!/usr/bin/env bash
# Builds MoltenVK from source at the pinned release into build/moltenvk: the static MoltenVK.xcframework
# with the iOS device and iOS Simulator slices, its headers, and the licences of everything compiled in.
# From that static library it links build/moltenvk/dynamic/MoltenVK.xcframework, one dynamic
# MoltenVK.framework that the app embeds once. MoltenVK is the Vulkan driver on iOS. There is no Vulkan
# loader: a layer-path core links MoltenVK.framework directly (CORE_USES_MOLTENVK=1 in core.env, which
# makes scripts/build-core.sh run this first). Two cores that each linked libMoltenVK.a put two copies of
# every MoltenVK Objective-C class in one process, which the runtime warns may crash (docs/06 section 2.5).
#
# Source: https://github.com/KhronosGroup/MoltenVK, Apache-2.0. MoltenVK's own fetchDependencies checks
# out each dependency at the commit the tag records in ExternalRevisions/*_repo_revision, so the tag pins
# them all (docs/03 section 5 lists them with their licences). Nothing here is committed: build/ is ignored.
#
#   scripts/build-moltenvk.sh      no-op when the pinned build is already there
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
version=v1.4.2
commit=db66022459ffb663aa2b50f6b018bc2e124f5edf
src="$root/build/moltenvk-src/MoltenVK"
derived="$root/build/moltenvk-src/DerivedData"
out="$root/build/moltenvk"
stamp="$version $commit"
min_ios=17.0

# One dynamic framework per slice, linked from the static library. Only the Vulkan entry points (vk*) are
# exported. Its own link, rather than MoltenVK's packaged dynamic framework, keeps the frameworks and the
# arm64-only simulator slice the cores use, and the no-JIT gate checks it like any other framework.
build_dynamic() {
    local slice sdk target dir framework
    rm -rf "$out/dynamic"
    for slice in ios-arm64 ios-arm64_x86_64-simulator; do
        sdk=iphoneos target="arm64-apple-ios$min_ios"
        [ "$slice" = ios-arm64 ] || sdk=iphonesimulator target="arm64-apple-ios$min_ios-simulator"
        dir="$out/dynamic/$sdk" framework="$out/dynamic/$sdk/MoltenVK.framework"
        mkdir -p "$framework"
        xcrun --sdk "$sdk" clang++ -dynamiclib -target "$target" -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" \
            -install_name @rpath/MoltenVK.framework/MoltenVK -compatibility_version 1 -current_version 1 \
            -Wl,-force_load,"$out/MoltenVK.xcframework/$slice/libMoltenVK.a" -Wl,-exported_symbol,'_vk*' \
            -Wl,-dead_strip -Wl,-x -framework Foundation -framework Metal -framework QuartzCore -framework IOSurface \
            -framework UIKit -framework CoreGraphics -o "$framework/MoltenVK"
        cat >"$framework/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>MoltenVK</string>
    <key>CFBundleIdentifier</key><string>com.zenithblue.gagaemu.moltenvk</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>MoltenVK</string>
    <key>CFBundlePackageType</key><string>FMWK</string>
    <key>CFBundleShortVersionString</key><string>${version#v}</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>MinimumOSVersion</key><string>$min_ios</string>
</dict>
</plist>
PLIST
        "$root/scripts/nojit-gate.sh" "$framework/MoltenVK"
    done
    xcodebuild -create-xcframework -output "$out/dynamic/MoltenVK.xcframework" \
        -framework "$out/dynamic/iphonesimulator/MoltenVK.framework" \
        -framework "$out/dynamic/iphoneos/MoltenVK.framework" >/dev/null
}

if [ -f "$out/MoltenVK.xcframework/Info.plist" ] && [ "$(cat "$out/VERSION" 2>/dev/null)" = "$stamp" ]; then
    [ -f "$out/dynamic/MoltenVK.xcframework/Info.plist" ] || build_dynamic
    exit 0
fi

if [ ! -d "$src/.git" ]; then
    rm -rf "$src"
    git clone --quiet --depth 1 --branch "$version" https://github.com/KhronosGroup/MoltenVK.git "$src"
fi
head=$(git -C "$src" rev-parse HEAD)
if [ "$head" != "$commit" ]; then
    echo "build/moltenvk-src/MoltenVK is at $head, but $version is $commit. Delete build/moltenvk-src and rerun." >&2
    exit 1
fi

# SPIRV-Tools uses MoltenVK's pregenerated headers (Templates/spirv-tools/build.zip), so no CMake build runs.
(cd "$src" && ./fetchDependencies --ios --iossim)

# The packaging step stages each platform in the derived data and builds one XCFramework from all of them.
for destination in "generic/platform=iOS" "generic/platform=iOS Simulator"; do
    xcodebuild build -quiet -project "$src/MoltenVKPackaging.xcodeproj" -scheme "MoltenVK Package (iOS only)" \
        -configuration Release -destination "$destination" -derivedDataPath "$derived"
done

package="$src/Package/Release/MoltenVK"
rm -rf "$out"
mkdir -p "$out/licenses"
cp -R "$package/static/MoltenVK.xcframework" "$out/"
cp -R "$package/include" "$out/include"
cp "$src/LICENSE" "$out/LICENSE"
# Compiled in: SPIRV-Cross, SPIRV-Tools and cereal. Headers only: Vulkan-Headers and SPIRV-Headers.
{
    echo "MoltenVK $version $commit Apache-2.0"
    for dep in SPIRV-Cross SPIRV-Tools cereal Vulkan-Headers SPIRV-Headers; do
        echo "$dep $(cat "$src/ExternalRevisions/${dep}_repo_revision")"
    done
} >"$out/DEPENDENCIES"
for dep in SPIRV-Cross SPIRV-Tools cereal Vulkan-Headers; do
    mkdir -p "$out/licenses/$dep"
    cp -R "$src/External/$dep"/LICENSE* "$out/licenses/$dep/" # SPIRV-Cross has a LICENSES folder too.
done
mkdir -p "$out/licenses/SPIRV-Headers"
cp -R "$src/External/SPIRV-Tools/external/spirv-headers"/LICENSE* "$out/licenses/SPIRV-Headers/"

for slice in ios-arm64 ios-arm64_x86_64-simulator; do
    [ -f "$out/MoltenVK.xcframework/$slice/libMoltenVK.a" ] || { echo "MoltenVK build has no $slice slice" >&2; exit 1; }
done
build_dynamic
echo "$stamp" >"$out/VERSION"
echo "MoltenVK $version: $out"
