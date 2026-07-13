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
    private var autoTypeService: AutoTypeService!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = AppState()
        self.state = state
        state.applyAppearance()

        clipboard = ClipboardService()
        autoTypeService = AutoTypeService()
        panelController = PanelController(state: state, clipboard: clipboard, autoType: autoTypeService)
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
            Dialogs.shortcutRegistrationFailed(state.l10n, shortcut: state.shortcut.displayName)
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

    func applicationWillTerminate(_ notification: Notification) {
        clipboard?.clearIfOwned()
    }
}
