# Conventions

Practices for iterating on this codebase. [architecture.md](architecture.md) describes what exists today; this describes how to add to it. Formatting is enforced by `swift-format` (the Xcode toolchain's, no extra dependency); everything else is held by review.

## Layering

Before writing code, decide which layer it belongs in (see architecture.md for the full picture):

- **Pure algorithms → `FlowerPasswordCore/`.** No AppKit, no state: the derivation, the Public Suffix List, text helpers.
- **State and orchestration → `FlowerPasswordDomain`.** Anything with branching that decides what happens (settings, session, delivery, clipboard clearing, shortcut rollback, geometry). It talks to the system only through the protocols in `Ports.swift` and gets a `swift test` unit test using fakes. The app target is covered only end to end by the UI tests, so logic left in `FlowerPassword/` is tested only through the UI.
- **System adapters → `Shell/`.** The AppKit/Carbon/ServiceManagement/Sparkle implementations of those protocols, plus the status item and panel window. Thin: no decisions worth a unit test.
- **View code → `UI/`.** A thin observer of `Settings` and `Session`; frames come from `PanelLayout`; no business logic.
- **Wiring → `Composition.swift`.** The only place that constructs the object graph.

## Style

- Formatting is `.swift-format` (4-space indent, 120 columns, import order left alone because Apple and project imports are grouped by hand). Run `xcrun swift-format format --in-place --recursive FlowerPassword FlowerPasswordUITests FlowerPasswordCore/Sources FlowerPasswordCore/Tests` before committing; CI runs the same paths with `lint --strict`. Plain `lint` exits 0 even with findings, so `--strict` is what makes it a check.
- Release and Debug builds treat Swift warnings as errors.
- Doc comments (`///`) only when the WHY isn't obvious from the code — a non-obvious invariant, a perf reason for a stored vs. computed property, a subtlety a reviewer would otherwise ask about. Don't restate what the signature already says. See `Settings.swift` for the calibration this repo uses.
- Group related constants in a nested `enum` (e.g. `Settings.Keys` for `UserDefaults` keys) rather than scattering string literals.
- No third-party dependencies beyond Sparkle (the updater). Anything else needs an explicit decision recorded in AGENTS.md.

## Adding a persisted setting

Follow the existing `Settings` pattern (`FlowerPasswordCore/Sources/FlowerPasswordDomain/Settings.swift`):

1. Add the key to `Settings.Keys`.
2. Add the `var`, with `didSet { defaults.set(...) }` if it must persist.
3. Load it in `init(defaults:)` with a safe fallback for a missing/invalid stored value, and cover that fallback in `SettingsTests`.
4. If it's user-facing, add a manual entry to `Localizable.xcstrings` with a comment and `en`, `zh-Hans`, and `zh-Hant` values, then use its generated symbol (`String(localized: .key)`). One sentence per entry with format specifiers for the variable parts, never concatenated fragments; numbers and sizes go through `formatted(_:)`.
5. Wire the control into `PanelFormView.swift`, reading/writing `Settings` directly (no intermediate view model).

## Algorithm and security-sensitive code

- `FlowerPasswordCore/Sources/FlowerPasswordCore/FlowerPassword.swift` and `golden_vectors.json` are frozen — they must match flowerpassword.com byte-for-byte. Do not touch them for a feature request; if a change seems to require it, stop and confirm with the user first.
- The memory password must never be written to disk (no logging it, no including it in crash reports, no new persistence path). Same bar for any new secret-like input.
- Any new network call needs an explicit reason — today the only one is the manual GitHub Releases update check. Don't add telemetry or background calls.

## Tests

- New Core logic ships with a test in `FlowerPasswordCoreTests/`, and new Domain logic in `FlowerPasswordDomainTests/`, following the existing `@Suite`/`@Test` (swift-testing) style of the sibling files.
- Domain tests never wait on the clock: use a zero delay and `await` the task itself (`ClipboardGuard.pendingClear`), or cancel it, instead of `Task.sleep`.
- Run `swift test --package-path FlowerPasswordCore` before committing anything under `FlowerPasswordCore/`.
- User-visible behavior of the app (panel, menu, clipboard, settings) gets a test in `FlowerPasswordUITests/`. Keep logic in Core with unit tests rather than testing it through the UI.
- Run `xcodebuild test -project FlowerPassword.xcodeproj -scheme FlowerPassword` before committing anything under `FlowerPassword/`.

## Accessibility

- Every control needs a VoiceOver name: set `setAccessibilityLabel` when the visible title is a symbol, a masked value, a bare URL, or a placeholder that disappears once the field has text.
- New controls get an accessibility identifier too; the UI tests find elements by it.
- Keep text at WCAG AA contrast (4.5:1, or 3:1 for large text) against the opaque tint in both palettes; the UI tests' accessibility audit checks it on Retina displays (1x displays such as CI's skip the pixel-based contrast check). The translucent panel falls back to an opaque tint under Reduce Transparency, so honor that for any new translucent surface.
- Actions that hide the panel announce their outcome with `NSAccessibility.post(… .announcementRequested …)`.

## Commits

Observed convention (`git log --oneline`), Conventional-Commits-lite, lowercase imperative summary:

```
<type>: <what changed, present tense, why if it's not obvious>
```

Types in use: `feat`, `fix`, `refactor`, `docs`, `chore`, `ci`. `chore: bump version to X.Y.Z` is its own commit, separate from the feature/fix commit — don't fold a version bump into a feature commit.

## Before shipping a change

- `swift test --package-path FlowerPasswordCore` passes (Core and Domain tests).
- `swift-format lint --strict` is clean (see Style).
- The UI tests pass.
- Every catalog entry is translated; this prints `[]`:
  `jq '[.strings | to_entries[] | select(.value.localizations["zh-Hans"].stringUnit.state != "translated" or .value.localizations["zh-Hant"].stringUnit.state != "translated") | .key]' FlowerPassword/Localizable.xcstrings`
- No new third-party dependency, no new persisted secret, no touched golden vectors.
- If the change affects the release/update chain, re-read the "Updates (Sparkle)", "Code signing" and "Releasing" sections of architecture.md — that flow has sharp edges (tag/version mismatch, `CFBundleVersion` must track the marketing version, partial-publish can't be repaired by re-running).
