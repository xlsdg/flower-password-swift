import AppKit

import FlowerPasswordCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var delivery: PasswordDelivery!
    private var panelController: PanelController!
    private var statusItemController: StatusItemController!
    private var hotkeyManager: HotkeyManager!
    private var updateChecker: UpdateChecker!

    func applicationDidFinishLaunching(_ notification: Notification) {
        installEditMenu()
        let arguments = CommandLine.arguments
        // Before anything that can block (modal dialogs), or a healthy install
        // gets rolled back on timeout.
        Self.acknowledgeUpdateHelper(arguments)

        // UI tests also skip the global hotkey, which an installed copy of the
        // app may already hold.
        let uiTesting = arguments.contains("--ui-testing")
        let defaults = uiTesting ? Self.uiTestingDefaults(arguments) : .standard

        let state = AppState(defaults: defaults)
        state.applyAppearance()

        delivery = PasswordDelivery(state: state)
        panelController = PanelController(state: state, delivery: delivery)
        hotkeyManager = HotkeyManager()
        updateChecker = UpdateChecker()
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
        if !uiTesting, !hotkeyManager.register(state.shortcut) {
            Dialogs.shortcutRegistrationFailed(shortcut: state.shortcut.displayName)
        }

        Task.detached(priority: .utility) {
            _ = PublicSuffix.shared
        }
    }

    /// Every release must keep this handshake (see docs/architecture.md).
    private static func acknowledgeUpdateHelper(_ arguments: [String]) {
        guard arguments.count == 3, arguments[1] == "--update-ready" else { return }
        do { try Data().write(to: URL(fileURLWithPath: arguments[2]), options: .atomic) }
        catch { NSLog("Could not acknowledge update startup: %@", error.localizedDescription) }
    }

    /// A private suite, wiped unless --keep-defaults relaunches to check
    /// persistence. The language lives in the standard domain, so the wipe
    /// clears it there.
    private static func uiTestingDefaults(_ arguments: [String]) -> UserDefaults {
        let suite = "org.xlsdg.flowerpassword.uitests"
        let defaults = UserDefaults(suiteName: suite)!
        if !arguments.contains("--keep-defaults") {
            LanguagePreference.current = .system
            defaults.removePersistentDomain(forName: suite)
        }
        return defaults
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        delivery?.clearClipboardIfOwned()
    }

    /// A minimal, invisible main menu with just the Edit menu. The app is
    /// menu-bar-only (no Dock icon), so this menu is never shown, but field
    /// editors (of NSTextField / NSSecureTextField) rely on the responder chain
    /// finding a menu item for standard editing commands to validate against.
    private func installEditMenu() {
        let mainMenu = NSMenu()
        let editMenu = NSMenu(title: "Edit")
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editItem.submenu = editMenu

        let items: [(String, Selector, String)] = [
            ("Undo", Selector(("undo:")), "z"),
            ("Redo", Selector(("redo:")), "Z"),
            ("Cut", #selector(NSText.cut(_:)), "x"),
            ("Copy", #selector(NSText.copy(_:)), "c"),
            ("Paste", #selector(NSText.paste(_:)), "v"),
            ("Select All", #selector(NSText.selectAll(_:)), "a"),
        ]
        for (title, action, key) in items {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = nil // route through responder chain
            editMenu.addItem(item)
        }

        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }
}
