import AppKit

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

    func deliver(_ password: String) {
        guard willAutoType else {
            copy(password)
            return
        }
        autoType.type(password) { [weak self] in
            self?.copy(password)
        }
    }

    /// The panel hides on delivery, so VoiceOver users hear the outcome instead.
    private func copy(_ password: String) {
        clipboard.copy(password)
        NSAccessibility.post(
            element: NSApp as Any, notification: .announcementRequested,
            userInfo: [
                .announcement: String(localized: .passwordCopied),
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ])
    }

    /// Flips from the *displayed* state, so a revoked trust re-prompts.
    func toggleAutoType() {
        guard !willAutoType else {
            state.autoType = false
            return
        }
        guard AutoTypeService.isTrusted(prompt: true) else {
            Dialogs.autoTypeNeedsPermission()
            return
        }
        state.autoType = true
    }

    func capturePreviousApp() {
        autoType.capturePreviousApp()
    }

    func clearClipboardIfOwned() {
        clipboard.clearIfOwned()
    }
}
