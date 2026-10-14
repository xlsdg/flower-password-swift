#!/bin/bash
# Builds, tests, and packages FlowerPassword.app into dist/ for a GitHub release.
set -euo pipefail

cd "$(dirname "$0")/.."

APP="build/Build/Products/Release/FlowerPassword.app"

swift test --package-path FlowerPasswordCore
# End-to-end UI tests; they need a logged-in GUI session and take over the
# mouse and clipboard for a few minutes.
xcodebuild test -project FlowerPassword.xcodeproj -scheme FlowerPassword -derivedDataPath build/test

xcodebuild -project FlowerPassword.xcodeproj -scheme FlowerPassword \
  -configuration Release -derivedDataPath build \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO clean build

# A fixed certificate keeps the designated requirement stable across builds,
# so Accessibility grants survive updates. Without SIGNING_IDENTITY the
# ad-hoc signature from xcodebuild stays (local builds).
# Sparkle's nested code is re-signed inside-out with the same identity so the
# bundle verifies. The app also needs disable-library-validation: a
# self-signed identity has no Team ID, and the hardened runtime otherwise
# refuses to load Sparkle.framework ("different Team IDs").
if [ -n "${SIGNING_IDENTITY:-}" ]; then
  sign() {
    codesign --force --options runtime --timestamp=none \
      ${SIGNING_KEYCHAIN:+--keychain "$SIGNING_KEYCHAIN"} \
      --sign "$SIGNING_IDENTITY" "$@"
  }
  SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
  sign --preserve-metadata=entitlements "$SPARKLE/XPCServices/Installer.xpc"
  sign --preserve-metadata=entitlements "$SPARKLE/XPCServices/Downloader.xpc"
  sign "$SPARKLE/Autoupdate"
  sign "$SPARKLE/Updater.app"
  sign "$APP/Contents/Frameworks/Sparkle.framework"
  sign --entitlements FlowerPassword/FlowerPassword.entitlements "$APP"
fi
codesign --verify --deep --strict "$APP"

# Read the version from the built product, not the pbxproj: the archive name
# must match what the shipped app reports, because release.yml checks it
# against the tag.
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
ZIP="dist/FlowerPassword-${VERSION}.zip"

mkdir -p dist
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

shasum -a 256 "$ZIP"
