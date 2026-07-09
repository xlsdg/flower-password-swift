#!/bin/bash
# Builds, tests, and packages FlowerPassword.app into dist/ for a GitHub release.
set -euo pipefail

cd "$(dirname "$0")/.."

APP="build/Build/Products/Release/FlowerPassword.app"

swift test --package-path FlowerPasswordCore

xcodebuild -project FlowerPassword.xcodeproj -scheme FlowerPassword \
  -configuration Release -derivedDataPath build \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO clean build

# Read the version from the built product, not the pbxproj: the archive name
# must match what the shipped app reports at runtime, because
# SelfUpdater.validate compares the two during in-place updates.
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
ZIP="dist/FlowerPassword-${VERSION}.zip"

mkdir -p dist
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

shasum -a 256 "$ZIP"
