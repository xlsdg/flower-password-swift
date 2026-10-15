# Conventions

How to add code; [architecture.md](architecture.md) describes what exists. `swift-format` enforces formatting; review holds the rest.

## Layering

Pick the layer before writing code:

- **Pure algorithms → `FlowerPasswordCore`.** No AppKit, no state.
- **State and orchestration → `FlowerPasswordDomain`.** Anything with branching that decides what happens. Reaches the system only through the `Ports.swift` protocols and gets a `swift test` unit test with fakes. Logic left in `FlowerPassword/` is covered only by the UI tests.
- **System adapters → `Shell/`.** Implement those protocols. Thin: no decisions worth a unit test.
- **Views → `UI/`.** Thin observers of `Settings` and `Session`; frames come from `PanelLayout`; no business logic.
- **Wiring → `Composition.swift`.** The only place that constructs the object graph.

## Style

- `.swift-format`: 4-space indent, 120 columns, import order untouched (Apple and project imports are grouped by hand). Plain `lint` exits 0 even with findings; `--strict` is what makes it a check.
- Release and Debug builds treat Swift warnings as errors.
- `///` doc comments only for a WHY the code can't show: a non-obvious invariant, a perf reason for stored vs. computed, a subtlety a reviewer would ask about. `Settings.swift` is the calibration.
- Group related constants in a nested `enum` (e.g. `Settings.Keys` for `UserDefaults` keys).

## Adding a persisted setting

Follow `FlowerPasswordCore/Sources/FlowerPasswordDomain/Settings.swift`:

1. Add the key to `Settings.Keys`.
2. Add the `var`, with `didSet { defaults.set(...) }` if it persists.
3. Load it in `init(defaults:)` with a safe fallback for a missing/invalid value; cover the fallback in `SettingsTests`.
4. If user-facing, add a manual `Localizable.xcstrings` entry with a comment and `en`, `zh-Hans`, `zh-Hant` values, and use its generated symbol (`String(localized: .key)`). One sentence per entry with format specifiers for the variable parts; numbers and sizes go through `formatted(_:)`.
5. Wire the control into `PanelFormView.swift`, reading/writing `Settings` directly (no view model).

## Tests

- New Core logic → `FlowerPasswordCoreTests/`; new Domain logic → `FlowerPasswordDomainTests/`. Match the siblings' swift-testing `@Suite`/`@Test` style.
- Domain tests never wait on the clock: use a zero delay, then `await` the task (`ClipboardGuard.pendingClear`) or cancel it.
- User-visible app behavior (panel, menu, clipboard, settings) → `FlowerPasswordUITests/`. Logic stays in the package with unit tests.

## Accessibility

- Every control has a VoiceOver name: `setAccessibilityLabel` when the visible title is a symbol, a masked value, a bare URL, or a placeholder that disappears once the field has text.
- Every new control gets an accessibility identifier; the UI tests find elements by it, so keep identifiers stable when renaming views.
- Text meets WCAG AA (4.5:1; 3:1 for large text) against the opaque tint in both palettes. The UI-test audit checks it on Retina only (1x displays, like CI's, skip the pixel contrast check). The translucent panel falls back to an opaque tint under Reduce Transparency; new translucent surfaces do the same.
- Actions that hide the panel announce their outcome via `NSAccessibility.post(… .announcementRequested …)`.

## Commits

Conventional-Commits-lite, lowercase imperative (see `git log --oneline`):

```
<type>: <what changed, why if not obvious>
```

Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `ci`. A version bump is its own `chore: bump version to X.Y.Z` commit.

## Before shipping

- Unit tests, UI tests, and `swift-format lint --strict` all pass (commands in AGENTS.md).
- Every catalog entry is translated; this prints `[]`:
  `jq '[.strings | to_entries[] | select(.value.localizations["zh-Hans"].stringUnit.state != "translated" or .value.localizations["zh-Hant"].stringUnit.state != "translated") | .key]' FlowerPassword/Localizable.xcstrings`
- Release/update chain touched → re-read Updates, Code signing, and Releasing in architecture.md.
