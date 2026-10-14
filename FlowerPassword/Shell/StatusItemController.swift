import AppKit

import FlowerPasswordDomain

/// The menu bar item: left-click toggles the panel below it, right-click
/// hides the panel and pops the context menu. The menu is built fresh on
/// every open, so checkmarks always reflect live state.
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let settings: Settings
    private let panels: PanelController
    private let shortcuts: ShortcutChanger
    private let updates: UpdateChecker
    private let delivery: PasswordDelivery

    init(
        settings: Settings, panels: PanelController, shortcuts: ShortcutChanger,
        updates: UpdateChecker, delivery: PasswordDelivery
    ) {
        self.settings = settings
        self.panels = panels
        self.shortcuts = shortcuts
        self.updates = updates
        self.delivery = delivery
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureButton()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let icon = NSImage(named: "Mono")
        icon?.isTemplate = true
        button.image = icon
        button.setAccessibilityIdentifier("statusItem")
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        let name = String(localized: .statusItemName)
        button.toolTip = name
        button.setAccessibilityLabel(name)
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            handleRightClick()
        } else {
            handleLeftClick()
        }
    }

    private func handleLeftClick() {
        guard let button = statusItem.button else { return }
        panels.toggleBelowStatusItem(button)
    }

    private func handleRightClick() {
        panels.hide()
        // Assign the menu just for this click so left-click keeps toggling
        // the panel instead of opening the menu.
        statusItem.menu = buildMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(
            ActionMenuItem(title: String(localized: .show)) { [weak self] in
                guard let self, let button = self.statusItem.button else { return }
                self.panels.showBelowStatusItem(button)
            })
        menu.addItem(.separator())

        menu.addItem(
            picker(String(localized: .theme), selected: settings.theme, name: \.title) { [weak self] mode in
                self?.settings.theme = mode
                mode.apply()
            })
        menu.addItem(
            picker(String(localized: .language), selected: LanguagePreference.current, name: \.title) {
                [weak self] preference in
                self?.changeLanguage(to: preference)
            })
        menu.addItem(
            picker(String(localized: .globalShortcut), selected: settings.shortcut, name: \.displayName) { [weak self] option in
                self?.shortcuts.change(to: option)
            })
        menu.addItem(.separator())

        menu.addItem(
            ActionMenuItem(title: String(localized: .launchAtLogin), checked: AutoLaunch.isEnabled) { [weak self] in
                self?.toggleAutoLaunch()
            })
        menu.addItem(
            ActionMenuItem(title: String(localized: .autoType), checked: delivery.willAutoType) { [weak self] in
                self?.delivery.toggleAutoType()
            })
        menu.addItem(
            ActionMenuItem(title: String(localized: .checkForUpdates)) { [weak self] in
                self?.updates.check()
            })
        menu.addItem(.separator())

        menu.addItem(
            ActionMenuItem(title: String(localized: .quit)) { [weak self] in
                self?.confirmQuit()
            })

        return menu
    }

    private func picker<T: CaseIterable & Equatable>(
        _ title: String, selected: T, name: (T) -> String, pick: @escaping (T) -> Void
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.items = T.allCases.map { value in
            ActionMenuItem(title: name(value), checked: value == selected) { pick(value) }
        }
        item.submenu = submenu
        return item
    }

    // MARK: - Actions

    private func toggleAutoLaunch() {
        do {
            try AutoLaunch.set(!AutoLaunch.isEnabled)
        } catch {
            Dialogs.autoLaunchFailed(detail: error.localizedDescription)
        }
    }

    private func confirmQuit() {
        panels.hide()
        if Dialogs.confirmQuit() {
            NSApp.terminate(nil)
        }
    }

    private func changeLanguage(to preference: LanguagePreference) {
        guard preference != LanguagePreference.current else { return }
        LanguagePreference.current = preference
        if Dialogs.confirmRelaunchForLanguage() {
            relaunch()
        }
    }

    /// A detached shell waits for this process to exit before reopening the
    /// app, so the new instance can register the global hotkey this one holds.
    private func relaunch() {
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = [
            "-c", "while /bin/kill -0 \"$1\" 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$2\"",
            "sh", String(ProcessInfo.processInfo.processIdentifier), Bundle.main.bundlePath,
        ]
        do {
            try helper.run()
        } catch {
            NSLog("Could not relaunch: %@", error.localizedDescription)
            return
        }
        NSApp.terminate(nil)
    }
}

/// NSMenuItem driving a closure — spares one @objc selector plus
/// representedObject plumbing per menu entry.
nonisolated private final class ActionMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(title: String, checked: Bool = false, handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        target = self
        state = checked ? .on : .off
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @MainActor @objc private func invoke() {
        handler()
    }
}
