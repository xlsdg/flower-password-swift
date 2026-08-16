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
    private let state: AppState
    private let autoType: AutoTypeService
    private let clipboard: ClipboardService

    init(state: AppState) {
        self.state = state
        self.autoType = AutoTypeService()
        self.clipboard = ClipboardService()
    }

    /// Auto-type when the user-facing setting is on AND Accessibility trust
    /// is live, clipboard otherwise. Checked every time it is read, so the
    /// menu checkmark never claims "on" once the system revokes trust.
    var willAutoType: Bool {
        state.autoType && AutoTypeService.isTrusted(prompt: false)
    }

    /// Delivers the password per `willAutoType`. If auto-type is desired but
    /// trust has been revoked since the menu was last opened, this falls
    /// back to clipboard without prompting.
    func deliver(_ password: String) {
        if willAutoType {
            autoType.type(password)
        } else {
            clipboard.copy(password)
        }
    }

    /// Flips auto-type from its currently *displayed* state. Enabling prompts
    /// for Accessibility permission if not already granted, and leaves the
    /// setting off if the user declines; disabling needs no prompt.
    func toggleAutoType() {
        guard !willAutoType else {
            state.autoType = false
            return
        }
        guard AutoTypeService.isTrusted(prompt: true) else {
            Dialogs.autoTypeNeedsPermission(state.l10n)
            return
        }
        state.autoType = true
    }

    /// Captures the app that had focus before the panel opens.
    func capturePreviousApp() {
        autoType.capturePreviousApp()
    }

    /// Clears the clipboard if this service owns it, e.g. on app termination.
    func clearClipboardIfOwned() {
        clipboard.clearIfOwned()
    }
}
