import AppKit

/// Shared NSAlert flows: `message` is the bold line, `detail` the smaller
/// text below it. Every alert activates the app first — an accessory app
/// otherwise keeps its modal stuck behind the frontmost app.
@MainActor
enum Dialogs {
    static func shortcutRegistrationFailed(_ l10n: L10n, shortcut: String) {
        runAlert(style: .critical, message: l10n.shortcutRegisterFailedMessage(shortcut))
    }

    static func autoLaunchFailed(_ l10n: L10n, detail: String) {
        runAlert(style: .critical, message: l10n.autoLaunchFailedMessage, detail: detail)
    }

    static func autoTypeNeedsPermission(_ l10n: L10n) {
        runAlert(
            style: .informational,
            message: l10n.autoTypePermissionMessage,
            detail: l10n.autoTypePermissionDetail
        )
    }

    /// Returns true when the user confirmed quitting.
    static func confirmQuit(_ l10n: L10n) -> Bool {
        ask(
            style: .informational, message: l10n.quitMessage,
            confirm: l10n.quitConfirm, dismiss: l10n.quitCancel)
    }

    /// Returns true when the user chose to install the update in place.
    static func updateAvailable(_ l10n: L10n, current: String, latest: String) -> Bool {
        ask(
            style: .informational, message: l10n.updateAvailableMessage(current, latest),
            detail: l10n.updateInstallDetail, confirm: l10n.updateInstallButton,
            dismiss: l10n.updateLaterButton)
    }

    /// Fallback for releases without a signed archive: returns true when
    /// the user chose to open the download page.
    static func updateAvailableManual(_ l10n: L10n, current: String, latest: String) -> Bool {
        ask(
            style: .informational, message: l10n.updateAvailableMessage(current, latest),
            detail: l10n.updateAvailableDetail, confirm: l10n.ok, dismiss: l10n.cancel)
    }

    /// Returns true when the user chose to open the download page after an
    /// in-place install failed.
    static func updateInstallFailed(_ l10n: L10n, detail: String) -> Bool {
        ask(
            style: .critical, message: l10n.updateInstallFailedMessage, detail: detail,
            confirm: l10n.updateOpenPageButton, dismiss: l10n.cancel)
    }

    static func noUpdate(_ l10n: L10n, version: String) {
        runAlert(
            style: .informational,
            message: l10n.updateNoUpdateMessage,
            detail: l10n.updateVersionMessage(version)
        )
    }

    static func updateError(_ l10n: L10n, detail: String) {
        runAlert(style: .critical, message: l10n.updateErrorMessage, detail: detail)
    }

    private static func ask(
        style: NSAlert.Style, message: String, detail: String? = nil,
        confirm: String, dismiss: String
    ) -> Bool {
        let alert = makeAlert(style: style, message: message, detail: detail)
        alert.addButton(withTitle: confirm)
        alert.addButton(withTitle: dismiss)
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    private static func makeAlert(style: NSAlert.Style, message: String, detail: String? = nil) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = message
        if let detail {
            alert.informativeText = detail
        }
        return alert
    }

    private static func runAlert(style: NSAlert.Style, message: String, detail: String? = nil) {
        let alert = makeAlert(style: style, message: message, detail: detail)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
