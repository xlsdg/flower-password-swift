# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A native macOS menu-bar app (Swift, SwiftUI/AppKit, zero third-party dependencies) that derives site-specific passwords from a memory password + distinction code using the Flower Password algorithm. Nothing is stored; the same inputs always yield the same password. Requires macOS 14+ and Xcode 16+.

## Commands

```bash
# Run the algorithm test suite (the only tests in the repo)
swift test --package-path FlowerPasswordCore

# Run a single test
swift test --package-path FlowerPasswordCore --filter FlowerPasswordTests/testName

# Build the app
xcodebuild -project FlowerPassword.xcodeproj -scheme FlowerPassword -configuration Release build

# Full release build: tests + universal (arm64/x86_64) build + zip into dist/
./scripts/release.sh
```

## Architecture

Two layers:

- **`FlowerPasswordCore/`** — a Swift Package (Swift 6 tools) with the pure logic: `FlowerPassword.swift` (the derivation algorithm), `PublicSuffix.swift` (registrable-domain extraction backed by the bundled `public_suffix_list.dat`), and `TextUtilities.swift`. All tests live here.
- **`FlowerPassword/`** — the app target (Xcode project) depending on the Core package. `main.swift` + `AppDelegate.swift` wire up the pieces; `AppState.swift` is the `@Observable` settings/state hub; `UI/` holds the SwiftUI panel; `Shell/` holds the AppKit/system integrations (status item, floating panel, global hotkey via Carbon, clipboard auto-clear, self-updater, launch-at-login, dialogs).

Key flows spanning multiple files:

- **Localization**: no `.lproj` bundles. `L10n.swift` defines all UI strings as plain Swift data for en-US / zh-CN / zh-TW so the language can switch at runtime without relaunch. New UI strings must be added to all three languages there.
- **Self-update chain**: `Shell/SelfUpdater.swift` verifies release archives against an Ed25519 public key embedded in the source. CI (`.github/workflows/release.yml`) signs archives with `scripts/sign-update.swift` using the `ED25519_PRIVATE_KEY` repo secret, and refuses to publish if the signature doesn't verify against the embedded key. `scripts/release.sh` names the zip after the built app's `CFBundleShortVersionString` because `SelfUpdater.validate` compares archive version to runtime version.
- **Clipboard → distinction code**: on panel show, a URL on the clipboard is reduced to its registrable domain (via `PublicSuffix`, lazily warmed off the main thread at launch) and prefilled as the distinction code.

## Constraints

- **The algorithm is frozen.** `FlowerPasswordCore/Sources/FlowerPasswordCore/FlowerPassword.swift` must match flowerpassword.com byte-for-byte (HMAC-MD5 construction); equivalence is enforced by the 42-case `golden_vectors.json` fixture in the Core tests. Never change the algorithm or the golden vectors.
- The memory password must never be written to disk, and the app makes no network requests except the manual update check/download against GitHub Releases.
- Only system frameworks (SwiftUI, AppKit, CryptoKit, Carbon, ServiceManagement) — do not add third-party dependencies.
