import AppKit

/// Shared NSAlert flows: `message` is the bold line, `detail` the smaller
/// text below it. Every alert activates the app first — an accessory app
/// otherwise keeps its modal stuck behind the frontmost app.
enum Dialogs {
    static func shortcutRegistrationFailed(shortcut: String) {
        show(.critical, String(localized: .shortcutRegistrationFailed(shortcut)))
    }

    static func autoLaunchFailed(detail: String) {
        show(.critical, String(localized: .autoLaunchFailed), detail: detail)
    }

    static func autoTypeNeedsPermission() {
        show(
            .informational, String(localized: .autoTypePermissionRequired),
            detail: String(localized: .autoTypePermissionDetail))
    }

    /// Returns true when the user confirmed quitting.
    static func confirmQuit() -> Bool {
        show(
            .informational, String(localized: .quitConfirmation),
            confirm: String(localized: .quitConfirm), dismiss: String(localized: .cancel))
    }

    /// Returns true when the user chose to relaunch now.
    static func confirmRelaunchForLanguage() -> Bool {
        show(
            .informational, String(localized: .relaunchForLanguage),
            confirm: String(localized: .relaunchNow), dismiss: String(localized: .later))
    }

    /// Runs the alert modally after activating the app. With `confirm` and
    /// `dismiss` it is a two-button question returning true for `confirm`;
    /// without them it is a plain notice with the system OK button.
    @discardableResult
    private static func show(
        _ style: NSAlert.Style, _ message: String, detail: String? = nil,
        confirm: String? = nil, dismiss: String? = nil
    ) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = message
        if let detail {
            alert.informativeText = detail
        }
        if let confirm, let dismiss {
            alert.addButton(withTitle: confirm)
            alert.addButton(withTitle: dismiss)
        }
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }
}
