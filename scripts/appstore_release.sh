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
# The archive step in nojit-gate.sh refuses a core outside GAGA_RELEASE_SET (default mgba). Widen it on purpose.
export GAGA_RELEASE_SET=${GAGA_RELEASE_SET:-mgba}
# Refuses the sideload profile, the Vulkan test core (debug and test builds only) and any core with a
# non-commercial licence (docs/03 section 5). The archive is checked again below.
scripts/nojit-gate.sh --release-set "$GAGA_CORE_SET"

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
  CODE_SIGN_STYLE=Automatic \
  GAGA_RELEASE=1
scripts/nojit-gate.sh --release-app "$ARCHIVE/Products/Applications/GagaEmu.app"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT" \
  -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates
for ipa in "$EXPORT"/*.ipa; do
  # The distribution-signed app: no get-task-allow, no JIT key, release cores only.
  scripts/nojit-gate.sh --release-ipa "$ipa"
done
echo "ipa: $EXPORT"
