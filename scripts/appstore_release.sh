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

xcodegen generate
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
