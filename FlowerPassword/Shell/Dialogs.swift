import AppKit

/// Shared NSAlert flows: `message` is the bold line, `detail` the smaller
/// text below it. Every alert activates the app first — an accessory app
/// otherwise keeps its modal stuck behind the frontmost app.
@MainActor
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

    /// Returns true when the user confirmed the signed in-place update.
    static func updateAvailableInstall(current: String, latest: String) -> Bool {
        show(
            .informational, String(localized: .updateAvailable(current, latest)),
            detail: String(localized: .updateInstallDetail),
            confirm: String(localized: .installAndRelaunch), dismiss: String(localized: .later))
    }

    /// Fallback for releases without a signed archive: returns true when
    /// the user chose to open the download page.
    static func updateAvailableManual(current: String, latest: String) -> Bool {
        show(
            .informational, String(localized: .updateAvailable(current, latest)),
            detail: String(localized: .updateManualDetail),
            confirm: String(localized: .ok), dismiss: String(localized: .cancel))
    }

    /// Returns true when the user chose to open the download page after an
    /// in-place install failed.
    static func updateInstallFailed(detail: String) -> Bool {
        show(
            .critical, String(localized: .updateInstallFailed), detail: detail,
            confirm: String(localized: .openDownloadPage), dismiss: String(localized: .cancel))
    }

    static func noUpdate(version: String) {
        show(.informational, String(localized: .upToDate), detail: String(localized: .currentVersion(version)))
    }

    static func updateError(detail: String) {
        show(.critical, String(localized: .updateCheckFailed), detail: detail)
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
