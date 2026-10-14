import AppKit

import FlowerPasswordCore
import FlowerPasswordDomain

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var composition: Composition?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installEditMenu()
        let arguments = CommandLine.arguments
        // UI tests also skip the global hotkey, which an installed copy of the
        // app may already hold.
        let uiTesting = arguments.contains("--ui-testing")
        let defaults = uiTesting ? Self.uiTestingDefaults(arguments) : .standard

        let settings = Settings(defaults: defaults)
        settings.theme.apply()

        let composition = Composition(settings: settings)
        self.composition = composition
        if !uiTesting {
            composition.shortcuts.registerCurrent()
        }

        Task.detached(priority: .utility) {
            _ = PublicSuffix.shared
        }
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
        composition?.clearClipboardIfOwned()
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
            item.target = nil  // route through responder chain
            editMenu.addItem(item)
        }

        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }
}
