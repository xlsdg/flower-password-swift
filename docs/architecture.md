# Architecture

Three layers; each depends only on those above it.

- **`FlowerPasswordCore/`**: Swift package (Swift 6 tools), pure logic. `FlowerPassword.swift` (the derivation; frozen, see AGENTS.md), `PublicSuffix.swift` (registrable domain from the bundled `public_suffix_list.dat`), `TextUtilities.swift`.
- **`FlowerPasswordDomain`**: second target of the same package, no AppKit. `Settings` (preferences, write-through to the injected `UserDefaults`), `Session` (memory password + distinction code, in memory only, plus URL prefill), `PanelLayout`/`PanelPlacement` (pure geometry), and the boundary orchestration (`PasswordDelivery`, `ClipboardGuard`, `ShortcutChanger`). These see the system only through the `Ports.swift` protocols, so `swift test` covers them with fakes.
- **`FlowerPassword/`**: app target (Xcode project), main-actor default isolation. `Composition.swift` builds the object graph once; `AppDelegate.swift` only holds it. `UI/`: the AppKit panel form; applies `PanelLayout` frames, observes `Settings`/`Session` via `withObservationTracking`. `Shell/`: system adapters implementing the Domain ports (`SystemPasteboard`, `AutoTypeService`, `HotkeyManager`, `SystemDeliveryNotifier`), plus status item, floating panel, browser URL reader, launch-at-login, dialogs, `Updater` (Sparkle).

## Cross-file flows

### Localization

- `FlowerPassword/Localizable.xcstrings` is the only UI-string source: `en` (source), `zh-Hans`, `zh-Hant`. The brand name and language names (English, 简体中文, 繁體中文) stay out of it.
- Every entry is `extractionState: manual`. `STRING_CATALOG_GENERATE_SYMBOLS` makes each key a `LocalizedStringResource` symbol: call sites read `String(localized: .memoryPassword)`, format specifiers become arguments (`.currentVersion(version)`), and a missing key fails to compile.
- The language resolves once at launch via `Bundle.main`. `Shell/LanguagePreference.swift` writes the menu choice to `AppleLanguages` in the app's own defaults domain (the value System Settings › Language & Region › Applications writes), then relaunches.

### Updates (Sparkle)

- `Shell/Updater.swift` wraps `SPUStandardUpdaterController`. `Info.plist` sets `SUFeedURL` (`releases/latest/download/appcast.xml`) and `SUPublicEDKey`, and disables scheduled checks and profiling: the feed is fetched only on "Check for Updates".
- Sparkle compares `CFBundleVersion`, so it tracks `MARKETING_VERSION`; a separate, never-bumped build number would make every release look older.
- `release.yml` runs `generate_appcast` with the `ED25519_PRIVATE_KEY` secret and fails if the appcast lacks `sparkle:edSignature` (the tool itself only warns when the key mismatches `SUPublicEDKey`).

### Code signing

- CI re-signs with one fixed self-signed certificate (`SIGNING_CERTIFICATE_P12` / `SIGNING_CERTIFICATE_PASSWORD` secrets, consumed by `scripts/release.sh`). The designated requirement becomes `identifier + certificate leaf`, not a per-build cdhash, so TCC grants (Accessibility for auto-type) survive updates. **Never rotate it**: every user would have to re-grant Accessibility. Backup/restore/recreate: [release-signing.md](release-signing.md).
- `scripts/release.sh` re-signs Sparkle's nested code inside-out with the same identity. The app carries `com.apple.security.cs.disable-library-validation`: a self-signed identity has no Team ID, so the hardened runtime would otherwise refuse `Sparkle.framework` and the Release app aborts at launch. Debug builds skip the hardened runtime and hide this.
- Local builds without `SIGNING_IDENTITY` stay ad-hoc.

### Releasing

- Bump the version in the Xcode project, then push a `v*` tag; CI fails unless the tag matches `CFBundleShortVersionString`.
- On success CI publishes the GitHub release (zip + `appcast.xml`) and bumps the Homebrew cask in `xlsdg/homebrew-tap`.
- A partial publish (release exists, asset missing) can't be repaired by re-running: delete the release, then re-run.

### UI tests

- `FlowerPasswordUITests/` drives the real app via XCUITest, including an accessibility audit of the panel in both themes. CI runs them on every push to main and every PR (`test.yml`); `scripts/release.sh` runs them before every release.
- Launched with `--ui-testing`, the app uses the private `org.xlsdg.flowerpassword.uitests` defaults suite (wiped at launch unless `--keep-defaults`), skips the global hotkey, and draws the panel tint opaque so the contrast audit measures the palette, not the desktop.
- Debug builds use bundle id `org.xlsdg.flowerpassword.debug`, so a test run never touches an installed release copy.
- Elements are found by accessibility identifier (`statusItem`, `password`, `key`, …).
- Manual only (they need permissions, change system state, or hit the network): global shortcut, auto-type, launch at login, updates.

### Browser tab / clipboard → distinction code

- On panel show, the first URL from the frontmost browser's active tab, then the clipboard, is reduced to its registrable domain (`PublicSuffix`, warmed lazily off the main thread at launch) and prefilled as the distinction code.
- `Shell/BrowserURLReader.swift` asks Safari and Chromium browsers over Apple Events (needs the `com.apple.security.automation.apple-events` entitlement, which `scripts/release.sh` must pass again when re-signing); for Gecko browsers it reads the `AXWebArea` URL, only if Accessibility is already granted.
- It runs before the panel activates; otherwise a first-use Automation prompt would dismiss the panel.
