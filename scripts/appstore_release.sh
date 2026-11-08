#!/bin/sh
# Release archive, then export an IPA for App Store Connect / TestFlight.
#   scripts/appstore_release.sh
# Needs a signed-in Apple ID in Xcode. Team is 9227VF8RW4
# (the Z7YCD23BTK in the cert name is not a team id).
set -eu
cd "$(dirname "$0")/.."
TEAM=9227VF8RW4
ARCHIVE=build/GagaEmu.xcarchive
EXPORT=build/release-export

# Every core except the non-commercial ones and vktest, GPL cores included (owner decision 2026-11-08,
# docs/03 section 5). The archive step in nojit-gate.sh refuses a core outside GAGA_RELEASE_SET, whose
# default is this same list.
GAGA_CORE_SET=${GAGA_CORE_SET:-$(scripts/nojit-gate.sh --default-release-set)}
export GAGA_CORE_SET
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
rm -rf "$EXPORT"
# Local export first (ExportOptions.plist says destination=upload, so flip it), gate the IPA, then upload.
sed 's|<string>upload</string>|<string>export</string>|' ExportOptions.plist > build/ExportOptions-export.plist
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT" \
  -exportOptionsPlist build/ExportOptions-export.plist \
  -allowProvisioningUpdates
for ipa in "$EXPORT"/*.ipa; do
  # The distribution-signed app: no get-task-allow, no JIT key, release cores only.
  scripts/nojit-gate.sh --release-ipa "$ipa"
done
echo "ipa: $EXPORT"
# Gate passed: upload the same archive.
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath build/release-upload \
  -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates
