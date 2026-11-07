#!/usr/bin/env bash
# Builds MoltenVK from source at the pinned release into build/moltenvk: the static MoltenVK.xcframework
# with the iOS device and iOS Simulator slices, its headers, and the licences of everything compiled in.
# MoltenVK is the Vulkan driver on iOS. There is no Vulkan loader: a layer-path core links libMoltenVK.a
# directly (CORE_USES_MOLTENVK=1 in core.env, which makes scripts/build-core.sh run this first).
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

if [ -f "$out/MoltenVK.xcframework/Info.plist" ] && [ "$(cat "$out/VERSION" 2>/dev/null)" = "$stamp" ]; then
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
echo "$stamp" >"$out/VERSION"
echo "MoltenVK $version: $out"
