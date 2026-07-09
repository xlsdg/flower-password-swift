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

    /// Returns true when the user confirmed quitting.
    static func confirmQuit(_ l10n: L10n) -> Bool {
        let alert = makeAlert(style: .informational, message: l10n.quitMessage)
        alert.addButton(withTitle: l10n.quitConfirm)
        alert.addButton(withTitle: l10n.quitCancel)
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Returns true when the user chose to open the download page.
    static func updateAvailable(_ l10n: L10n, current: String, latest: String) -> Bool {
        let message = l10n.updateAvailableMessage(current, latest)
        let alert = makeAlert(style: .informational, message: message, detail: l10n.updateAvailableDetail)
        alert.addButton(withTitle: l10n.ok)
        alert.addButton(withTitle: l10n.cancel)
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
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
