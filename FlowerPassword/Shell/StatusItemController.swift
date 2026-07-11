import AppKit

/// The menu bar item: left-click toggles the panel below it, right-click
/// hides the panel and pops the context menu. The menu is built fresh on
/// every open, so checkmarks always reflect live state.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let state: AppState
    private let panels: PanelController
    private let hotkeys: HotkeyManager
    private let updates: UpdateChecker

    init(state: AppState, panels: PanelController, hotkeys: HotkeyManager, updates: UpdateChecker) {
        self.state = state
        self.panels = panels
        self.hotkeys = hotkeys
        self.updates = updates
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureButton()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let icon = NSImage(named: "Mono")
        icon?.isTemplate = true
        button.image = icon
        button.toolTip = L10n.strings(for: state.effectiveLanguage).trayTooltip
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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
        if panels.isVisible {
            panels.hide()
            return
        }
        // If the panel lost key status (and hid) because of this very click,
        // this is a dismiss, not an open request.
        guard Date().timeIntervalSince(panels.lastHiddenAt) > 0.3 else { return }
        showPanel()
    }

    private func handleRightClick() {
        if panels.isVisible {
            panels.hide()
        }
        // Assign the menu just for this click so left-click keeps toggling
        // the panel instead of opening the menu.
        statusItem.menu = buildMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - Menu

    /// Show / Theme / Language / auto-launch / shortcut / update / Quit,
    /// with the pickers as native checkmarked submenus.
    private func buildMenu() -> NSMenu {
        let l10n = L10n.strings(for: state.effectiveLanguage)
        let menu = NSMenu()

        menu.addItem(
            ActionMenuItem(title: l10n.trayShow) { [weak self] in
                self?.showPanel()
            })
        menu.addItem(.separator())

        menu.addItem(submenuItem(title: l10n.menuTheme, items: themeItems(l10n)))
        menu.addItem(submenuItem(title: l10n.menuLanguage, items: languageItems(l10n)))
        menu.addItem(.separator())

        menu.addItem(
            ActionMenuItem(title: l10n.menuAutoLaunch, checked: AutoLaunch.isEnabled) { [weak self] in
                self?.toggleAutoLaunch()
            })
        menu.addItem(
            ActionMenuItem(title: l10n.menuAutoType, checked: state.autoType) { [weak self] in
                self?.toggleAutoType()
            })
        menu.addItem(submenuItem(title: l10n.menuGlobalShortcut, items: shortcutItems()))
        menu.addItem(
            ActionMenuItem(title: l10n.menuCheckUpdate) { [weak self] in
                self?.updates.check()
            })
        menu.addItem(.separator())

        menu.addItem(
            ActionMenuItem(title: l10n.trayQuit) { [weak self] in
                self?.confirmQuit()
            })

        return menu
    }

    private func themeItems(_ l10n: L10n) -> [NSMenuItem] {
        ThemeMode.allCases.map { mode in
            ActionMenuItem(title: l10n.themeName(mode), checked: state.theme == mode) { [weak self] in
                self?.state.theme = mode
            }
        }
    }

    private func languageItems(_ l10n: L10n) -> [NSMenuItem] {
        LanguageMode.allCases.map { mode in
            ActionMenuItem(title: l10n.languageName(mode), checked: state.language == mode) { [weak self] in
                guard let self else { return }
                self.state.language = mode
                self.refreshTooltip()
            }
        }
    }

    private func shortcutItems() -> [NSMenuItem] {
        ShortcutOption.allCases.map { option in
            ActionMenuItem(title: option.displayName, checked: state.shortcut == option) { [weak self] in
                self?.changeShortcut(to: option)
            }
        }
    }

    private func submenuItem(title: String, items: [NSMenuItem]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for entry in items {
            submenu.addItem(entry)
        }
        item.submenu = submenu
        return item
    }

    // MARK: - Actions

    private func showPanel() {
        if let button = statusItem.button {
            panels.showBelowStatusItem(button)
        }
    }

    private func refreshTooltip() {
        statusItem.button?.toolTip = L10n.strings(for: state.effectiveLanguage).trayTooltip
    }

    private func toggleAutoLaunch() {
        do {
            try AutoLaunch.set(!AutoLaunch.isEnabled)
        } catch {
            Dialogs.autoLaunchFailed(
                L10n.strings(for: state.effectiveLanguage),
                detail: error.localizedDescription
            )
        }
    }

    /// Requests Accessibility permission (with the system prompt) before
    /// enabling; the setting is left off if permission isn't granted.
    private func toggleAutoType() {
        guard !state.autoType else {
            state.autoType = false
            return
        }
        guard AutoTypeService.isTrusted(prompt: true) else {
            Dialogs.autoTypeNeedsPermission(L10n.strings(for: state.effectiveLanguage))
            return
        }
        state.autoType = true
    }

    /// The new choice is registered before it is persisted; on failure the
    /// previous shortcut is restored, so a working hotkey is never lost.
    private func changeShortcut(to option: ShortcutOption) {
        guard option != state.shortcut else { return }
        if hotkeys.register(option) {
            state.shortcut = option
        } else {
            hotkeys.register(state.shortcut)
            Dialogs.shortcutRegistrationFailed(
                L10n.strings(for: state.effectiveLanguage),
                shortcut: option.displayName
            )
        }
    }

    private func confirmQuit() {
        panels.hide()
        if Dialogs.confirmQuit(L10n.strings(for: state.effectiveLanguage)) {
            NSApp.terminate(nil)
        }
    }
}

/// NSMenuItem driving a closure — spares one @objc selector plus
/// representedObject plumbing per menu entry.
private final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, checked: Bool = false, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        target = self
        state = checked ? .on : .off
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func invoke() {
        handler()
    }
}
