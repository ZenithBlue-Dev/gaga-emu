#!/bin/sh
# Release archive, then export an IPA for App Store Connect / TestFlight.
#   scripts/appstore_release.sh
# Needs a signed-in Apple ID in Xcode. Team is 9227VF8RW4
# (the Z7YCD23BTK in the cert name is not a team id).
set -eu
cd "$(dirname "$0")/.."
TEAM=9227VF8RW4
ARCHIVE=build/GagaEmu.xcarchive
EXPORT=build/export

# GPL cores do not ship while the legal gate is open (docs/07 milestone 4.0). This is the MPL-only set.
GAGA_CORE_SET=${GAGA_CORE_SET:-mgba}
export GAGA_CORE_SET
# The Vulkan test core (Cores/vktest) is for debug and test builds only.
case " $GAGA_CORE_SET " in *" vktest "*) echo "GAGA_CORE_SET must not include vktest in a release" >&2; exit 1 ;; esac

git submodule update --init
# shellcheck disable=SC2086 # a word list.
scripts/build-core.sh $GAGA_CORE_SET
scripts/generate-project.sh
xcodebuild -project GagaEmu.xcodeproj -scheme GagaEmu \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  archive \
  DEVELOPMENT_TEAM="$TEAM" \
  CODE_SIGN_STYLE=Automatic
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT" \
  -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates
echo "ipa: $EXPORT"
