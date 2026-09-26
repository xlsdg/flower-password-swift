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

        // Acknowledge the update helper before anything that can block (modal
        // dialogs), or a healthy install gets rolled back on timeout. Every
        // release must keep this handshake (see docs/architecture.md).
        let arguments = CommandLine.arguments
        if arguments.count == 3, arguments[1] == "--update-ready" {
            do { try Data().write(to: URL(fileURLWithPath: arguments[2]), options: .atomic) }
            catch { NSLog("Could not acknowledge update startup: %@", error.localizedDescription) }
        }

        // UI tests run against a private defaults suite, wiped unless
        // --keep-defaults relaunches to check persistence, and skip the global
        // hotkey, which an installed copy of the app may already hold. The
        // language lives in the standard domain, so the wipe clears it there.
        let uiTesting = arguments.contains("--ui-testing")
        let resetDefaults = uiTesting && !arguments.contains("--keep-defaults")
        if resetDefaults { LanguagePreference.current = .system }
        let defaults = uiTesting ? Self.uiTestingDefaults(reset: resetDefaults) : .standard

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

        // The Public Suffix List (used to prefill the distinction code from
        // clipboard URLs) parses lazily; warm it off the main thread.
        Task.detached(priority: .utility) {
            _ = PublicSuffix.shared
        }
    }

    private static func uiTestingDefaults(reset: Bool) -> UserDefaults {
        let suite = "org.xlsdg.flowerpassword.uitests"
        let defaults = UserDefaults(suiteName: suite)!
        if reset { defaults.removePersistentDomain(forName: suite) }
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
