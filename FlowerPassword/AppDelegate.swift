import AppKit

import FlowerPasswordCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var state: AppState!
    private var delivery: PasswordDelivery!
    private var panelController: PanelController!
    private var statusItemController: StatusItemController!
    private var hotkeyManager: HotkeyManager!
    private var updateChecker: UpdateChecker!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = AppState()
        self.state = state
        state.applyAppearance()

        let clipboard = ClipboardService()
        let autoTypeService = AutoTypeService()
        delivery = PasswordDelivery(state: state, autoType: autoTypeService, clipboard: clipboard)
        panelController = PanelController(state: state, delivery: delivery)
        hotkeyManager = HotkeyManager()
        updateChecker = UpdateChecker(state: state)
        statusItemController = StatusItemController(
            state: state,
            panels: panelController,
            hotkeys: hotkeyManager,
            updates: updateChecker,
            delivery: delivery
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
        delivery?.clearClipboardIfOwned()
    }
}
