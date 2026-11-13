#!/usr/bin/env bash
# Xcode build step, before the no-JIT gate. In the DevJIT configuration only, replaces each embedded core that has a
# sideload JIT build in build/cores-jit (GAGA_JIT=1 scripts/build-core.sh <core>) with that build, and signs it as
# the embed step would. Same framework name, install name and single export, so the app links either. Every other
# configuration, any archive and any release build changes nothing; scripts/nojit-gate.sh refuses a JIT core there.
set -euo pipefail

[ "${CONFIGURATION:-}" = DevJIT ] && [ "${ACTION:-}" != install ] && [ "${GAGA_RELEASE:-}" != 1 ] || exit 0
root=$(cd "$(dirname "$0")/.." && pwd)
slice=ios-arm64
[ "${PLATFORM_NAME:-}" != iphonesimulator ] || slice=ios-arm64-simulator
frameworks="$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH"
for xcframework in "$root"/build/cores-jit/*.xcframework; do
    [ -d "$xcframework" ] || continue
    name=$(basename "$xcframework" .xcframework)
    # Only a core this build already embeds (GAGA_CORE_SET): the gate refuses one outside the set.
    [ -d "$frameworks/$name.framework" ] || continue
    rm -rf "$frameworks/$name.framework"
    cp -R "$xcframework/$slice/$name.framework" "$frameworks/"
    if [ "${CODE_SIGNING_ALLOWED:-}" = YES ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
        codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp=none --preserve-metadata=identifier,entitlements,flags \
            "$frameworks/$name.framework"
    fi
    echo "DevJIT: $name is the sideload JIT build"
done
