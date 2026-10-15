# AGENTS.md

Native macOS menu-bar app (Swift + AppKit, macOS 14+, Xcode 26+) that derives site passwords from a memory password + distinction code via the Flower Password algorithm. Stateless: same inputs → same password, nothing stored.

## Commands

```bash
# Unit tests: Core + Domain (swift-testing; --filter takes a @Suite type or @Test name)
swift test --package-path FlowerPasswordCore
swift test --package-path FlowerPasswordCore --filter PublicSuffixTests

# UI tests: drive the real app, take over mouse + clipboard, ~4 min
xcodebuild test -project FlowerPassword.xcodeproj -scheme FlowerPassword
xcodebuild test -project FlowerPassword.xcodeproj -scheme FlowerPassword \
  -only-testing:FlowerPasswordUITests/FlowerPasswordUITests/testEscClosesPanel

# Format (CI: same paths with `lint --strict`)
xcrun swift-format format --in-place --recursive FlowerPassword FlowerPasswordUITests FlowerPasswordCore/Sources FlowerPasswordCore/Tests

# Build; full release = all tests + universal build + zip → dist/
xcodebuild -project FlowerPassword.xcodeproj -scheme FlowerPassword -configuration Release build
./scripts/release.sh
```

Before committing: touched `FlowerPasswordCore/` → unit tests green; touched `FlowerPassword/` → UI tests green.

## Docs

- `docs/architecture.md`: read before touching localization, Sparkle updates, code signing, releasing, the UI-test harness, or browser/clipboard → distinction-code prefill.
- `docs/conventions.md`: read before adding code: layer placement, style, new persisted setting, tests, commits, pre-ship checklist.

## Hard rules

- **Algorithm frozen.** `FlowerPasswordCore/Sources/FlowerPasswordCore/FlowerPassword.swift` (HMAC-MD5) matches flowerpassword.com byte-for-byte, pinned by `golden_vectors.json`. Leave both as-is; if a task seems to need changing them, stop and ask.
- Memory password lives only in memory: never disk, logs, or crash reports.
- Network: only the manual Sparkle update check against GitHub Releases.
- Dependencies: system frameworks + Sparkle. UI is pure AppKit, no SwiftUI.
