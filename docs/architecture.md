# Architecture

Two layers:

- **`FlowerPasswordCore/`** — a Swift Package (Swift 6 tools) with the pure logic: `FlowerPassword.swift` (the derivation algorithm), `PublicSuffix.swift` (registrable-domain extraction backed by the bundled `public_suffix_list.dat`), `ResolvedLanguage.swift` (system-locale → UI-language mapping), `ReleaseDecision.swift` (maps a decoded GitHub release manifest to an up-to-date/installable/manual-only outcome), and `TextUtilities.swift`. All tests live here; the app target has no test target, so pure, testable logic belongs in Core.
- **`FlowerPassword/`** — the app target (Xcode project) depending on the Core package. `main.swift` + `AppDelegate.swift` wire up the pieces; `AppState.swift` is the `@Observable` settings/state hub; `UI/` holds the AppKit panel form (observes `AppState` via `withObservationTracking`); `Shell/` holds the AppKit/system integrations (status item, floating panel, global hotkey via Carbon, clipboard auto-clear, self-updater, launch-at-login, dialogs).

## Key flows spanning multiple files

- **Localization**: no `.lproj` bundles. `L10n.swift` defines all UI strings as plain Swift data for en-US / zh-CN / zh-TW so the language can switch at runtime without relaunch. New UI strings must be added to all three languages there.
- **Self-update chain**: `Shell/SelfUpdater.swift` verifies release archives against an Ed25519 public key embedded in the source. CI (`.github/workflows/release.yml`) signs archives with `scripts/sign-update.swift` using the `ED25519_PRIVATE_KEY` repo secret, and refuses to publish if the signature doesn't verify against the embedded key. `scripts/release.sh` names the zip after the built app's `CFBundleShortVersionString` because `SelfUpdater.validate` compares archive version to runtime version.
- **Releasing**: push a `v*` tag; CI fails unless the tag matches the app's `CFBundleShortVersionString`, so bump the version in the Xcode project first. On success CI creates the GitHub release (zip + `.zip.sig`) and auto-bumps the Homebrew cask in the separate `xlsdg/homebrew-tap` repo. A partial publish (release exists but an asset is missing) cannot be repaired by re-running — delete the release and re-run.
- **Clipboard → distinction code**: on panel show, a URL on the clipboard is reduced to its registrable domain (via `PublicSuffix`, lazily warmed off the main thread at launch) and prefilled as the distinction code.
