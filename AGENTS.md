# AGENTS.md

This file provides guidance to agentic coding tools when working with code in this repository.

## Project

A native macOS menu-bar app (Swift, SwiftUI/AppKit, zero third-party dependencies) that derives site-specific passwords from a memory password + distinction code using the Flower Password algorithm. Nothing is stored; the same inputs always yield the same password. Requires macOS 14+ and Xcode 16+.

## Commands

```bash
# Run the algorithm test suite (the only tests in the repo)
swift test --package-path FlowerPasswordCore

# Run a single test (swift-testing: filter by @Suite type or @Test function name)
swift test --package-path FlowerPasswordCore --filter PublicSuffixTests
swift test --package-path FlowerPasswordCore --filter urlText

# Build the app
xcodebuild -project FlowerPassword.xcodeproj -scheme FlowerPassword -configuration Release build

# Full release build: tests + universal (arm64/x86_64) build + zip into dist/
./scripts/release.sh
```

Verification: run `swift test --package-path FlowerPasswordCore` before committing anything that touches `FlowerPasswordCore/`.

## Architecture

See [docs/architecture.md](docs/architecture.md) for the layer breakdown and the cross-file flows (localization, self-update chain, releasing, clipboard → distinction code).

## Constraints

- **The algorithm is frozen.** `FlowerPasswordCore/Sources/FlowerPasswordCore/FlowerPassword.swift` must match flowerpassword.com byte-for-byte (HMAC-MD5 construction); equivalence is enforced by the 42-case `golden_vectors.json` fixture in the Core tests. Never change the algorithm or the golden vectors.
- The memory password must never be written to disk, and the app makes no network requests except the manual update check/download against GitHub Releases.
- Only system frameworks (SwiftUI, AppKit, CryptoKit, Carbon, ServiceManagement) — do not add third-party dependencies.
