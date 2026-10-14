import AppKit

import FlowerPasswordDomain

/// Builds the object graph once and keeps every long-lived object alive.
/// The graph has no cycles, so dependencies are plain constructor arguments.
final class Composition {
    private let clipboard: ClipboardGuard
    private let panels: PanelController
    private let statusItem: StatusItemController
    private let hotkeys = HotkeyManager()
    private let updater = Updater()
    let shortcuts: ShortcutChanger

    init(settings: Settings) {
        let session = Session()
        let autoTyper = AutoTypeService()
        clipboard = ClipboardGuard(pasteboard: SystemPasteboard())
        let delivery = PasswordDelivery(
            settings: settings, clipboard: clipboard, typer: autoTyper,
            notifier: SystemDeliveryNotifier())
        shortcuts = ShortcutChanger(settings: settings, registry: hotkeys) {
            Dialogs.shortcutRegistrationFailed(shortcut: $0.displayName)
        }
        panels = PanelController(
            settings: settings, session: session, delivery: delivery, autoTyper: autoTyper)
        statusItem = StatusItemController(
            settings: settings, panels: panels, shortcuts: shortcuts, updater: updater,
            delivery: delivery)
        hotkeys.handler = { [panels] in panels.showAtCursor() }
    }

    func clearClipboardIfOwned() {
        clipboard.clearIfOwned()
    }
}
