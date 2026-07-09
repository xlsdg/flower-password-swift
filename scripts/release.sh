#!/bin/bash
# Builds, tests, and packages FlowerPassword.app into dist/ for a GitHub release.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION=$(grep -m1 MARKETING_VERSION FlowerPassword.xcodeproj/project.pbxproj | sed 's/[^0-9.]//g')
APP="build/Build/Products/Release/FlowerPassword.app"
ZIP="dist/FlowerPassword-${VERSION}.zip"

swift test --package-path FlowerPasswordCore

xcodebuild -project FlowerPassword.xcodeproj -scheme FlowerPassword \
  -configuration Release -derivedDataPath build \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO clean build

mkdir -p dist
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

shasum -a 256 "$ZIP"
