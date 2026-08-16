import AppKit

/// Shared NSAlert flows: `message` is the bold line, `detail` the smaller
/// text below it. Every alert activates the app first — an accessory app
/// otherwise keeps its modal stuck behind the frontmost app.
@MainActor
enum Dialogs {
    static func shortcutRegistrationFailed(_ l10n: L10n, shortcut: String) {
        show(.critical, l10n.shortcutRegisterFailedMessage(shortcut))
    }

    static func autoLaunchFailed(_ l10n: L10n, detail: String) {
        show(.critical, l10n.autoLaunchFailedMessage, detail: detail)
    }

    static func autoTypeNeedsPermission(_ l10n: L10n) {
        show(.informational, l10n.autoTypePermissionMessage, detail: l10n.autoTypePermissionDetail)
    }

    /// Returns true when the user confirmed quitting.
    static func confirmQuit(_ l10n: L10n) -> Bool {
        show(.informational, l10n.quitMessage, confirm: l10n.quitConfirm, dismiss: l10n.quitCancel)
    }

    /// Returns true when the user confirmed the signed in-place update.
    static func updateAvailableInstall(_ l10n: L10n, current: String, latest: String) -> Bool {
        show(
            .informational, l10n.updateAvailableMessage(current, latest),
            detail: l10n.updateInstallDetail,
            confirm: l10n.updateInstallButton, dismiss: l10n.updateLaterButton)
    }

    /// Fallback for releases without a signed archive: returns true when
    /// the user chose to open the download page.
    static func updateAvailableManual(_ l10n: L10n, current: String, latest: String) -> Bool {
        show(
            .informational, l10n.updateAvailableMessage(current, latest),
            detail: l10n.updateAvailableDetail, confirm: l10n.ok, dismiss: l10n.cancel)
    }

    /// Returns true when the user chose to open the download page after an
    /// in-place install failed.
    static func updateInstallFailed(_ l10n: L10n, detail: String) -> Bool {
        show(
            .critical, l10n.updateInstallFailedMessage, detail: detail,
            confirm: l10n.updateOpenPageButton, dismiss: l10n.cancel)
    }

    static func noUpdate(_ l10n: L10n, version: String) {
        show(.informational, l10n.updateNoUpdateMessage, detail: l10n.updateVersionMessage(version))
    }

    static func updateError(_ l10n: L10n, detail: String) {
        show(.critical, l10n.updateErrorMessage, detail: detail)
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
