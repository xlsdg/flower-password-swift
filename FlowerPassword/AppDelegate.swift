import AppKit

import FlowerPasswordCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var state: AppState!
    private var clipboard: ClipboardService!
    private var panelController: PanelController!
    private var statusItemController: StatusItemController!
    private var hotkeyManager: HotkeyManager!
    private var updateChecker: UpdateChecker!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = AppState()
        self.state = state
        state.applyAppearance()

        clipboard = ClipboardService()
        panelController = PanelController(state: state, clipboard: clipboard)
        hotkeyManager = HotkeyManager()
        updateChecker = UpdateChecker(state: state)
        statusItemController = StatusItemController(
            state: state,
            panels: panelController,
            hotkeys: hotkeyManager,
            updates: updateChecker
        )

        hotkeyManager.handler = { [weak self] in
            self?.panelController.showAtCursor()
        }
        if !hotkeyManager.register(state.shortcut) {
            Dialogs.shortcutRegistrationFailed(
                L10n.strings(for: state.effectiveLanguage),
                shortcut: state.shortcut.displayName
            )
        }

        // The Public Suffix List (used to prefill the distinction code from
        // clipboard URLs) parses lazily; warm it off the main thread.
        Task.detached(priority: .utility) {
            _ = PublicSuffix.shared
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
