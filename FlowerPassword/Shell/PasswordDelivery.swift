import AppKit

/// Owns the password delivery decision: when the user generates a password,
/// should it be typed directly into the focused field (auto-type) or copied
/// to the clipboard? The rule is: auto-type when both the user-facing setting
/// is enabled AND the process still holds Accessibility trust; clipboard
/// otherwise.
///
/// Callers invoke `deliver(_:)` and never re-implement the rule themselves.
@MainActor
final class PasswordDelivery {
    enum Mode {
        case autoType
        case clipboard
    }

    private let state: AppState
    private let autoType: AutoTypeService
    private let clipboard: ClipboardService

    init(state: AppState, autoType: AutoTypeService, clipboard: ClipboardService) {
        self.state = state
        self.autoType = autoType
        self.clipboard = clipboard
    }

    /// The delivery mode that would be used right now: auto-type when the
    /// user-facing setting is on AND Accessibility trust is live, clipboard
    /// otherwise. Checked every time it is read, so the menu checkmark never
    /// claims "on" once the system revokes trust.
    var desiredMode: Mode {
        state.autoType && AutoTypeService.isTrusted(prompt: false) ? .autoType : .clipboard
    }

    /// Delivers the password using the current mode. If auto-type is desired
    /// but trust has been revoked since the menu was last opened, this falls
    /// back to clipboard without prompting.
    func deliver(_ password: String) {
        switch desiredMode {
        case .autoType:
            autoType.type(password)
        case .clipboard:
            clipboard.copy(password)
        }
    }

    /// Requests enabling or disabling auto-type. When enabling, prompts for
    /// Accessibility permission if not already granted; the setting remains
    /// off if the user declines. When disabling, no prompt — the setting is
    /// turned off immediately.
    func setAutoTypeEnabled(_ enabled: Bool) {
        guard enabled else {
            state.autoType = false
            return
        }
        guard AutoTypeService.isTrusted(prompt: true) else {
            Dialogs.autoTypeNeedsPermission(state.l10n)
            return
        }
        state.autoType = true
    }

    /// Flips auto-type from its currently *displayed* state — off when the
    /// checkmark reads off, including when trust was revoked behind the
    /// user's back and the persisted flag hasn't caught up yet.
    func toggleAutoType() {
        setAutoTypeEnabled(desiredMode != .autoType)
    }

    /// Captures the app that had focus before the panel opens, so auto-type
    /// can reactivate it and inject keystrokes into the right target.
    func capturePreviousApp() {
        autoType.capturePreviousApp()
    }

    /// Immediately clears the clipboard if this service owns it. Called on
    /// app termination to honor the 10-second promise even when the scheduled
    /// work item dies with the process.
    func clearClipboardIfOwned() {
        clipboard.clearIfOwned()
    }
}
