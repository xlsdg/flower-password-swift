import AppKit

import FlowerPasswordCore
import FlowerPasswordDomain

final class PanelController: NSObject, NSWindowDelegate {
    private let panel: FloatingPanel
    private let settings: Settings
    private let session: Session
    private let delivery: PasswordDelivery
    private let autoTyper: AutoTypeService

    /// Set every time the panel hides, used internally to distinguish
    /// "just hid due to focus loss from this very click" from a fresh toggle.
    private var lastHiddenAt = Date.distantPast

    init(settings: Settings, session: Session, delivery: PasswordDelivery, autoTyper: AutoTypeService) {
        self.settings = settings
        self.session = session
        self.delivery = delivery
        self.autoTyper = autoTyper
        self.panel = FloatingPanel()
        super.init()

        let actions = PanelActions(
            copyAndHide: { [weak self] code in
                guard let self else { return }
                self.hide()
                self.delivery.deliver(code)
            },
            hide: { [weak self] in
                self?.hide()
            }
        )

        let effectView = NSVisualEffectView()
        effectView.material = .underWindowBackground
        effectView.blendingMode = .behindWindow
        effectView.state = .active

        // Corner clipping must live on a plain container: an effectView's
        // backdrop is a private sublayer that ignores its own layer's
        // cornerRadius, leaving pale square nubs poking past the rounded mask.
        let container = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        container.wantsLayer = true
        container.layer?.cornerRadius = PanelMetrics.cornerRadius
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true

        let formView = PanelFormView(settings: settings, session: session, actions: actions)
        for (child, parent) in [(effectView, container), (formView, effectView)] as [(NSView, NSView)] {
            child.frame = parent.bounds
            child.autoresizingMask = [.width, .height]
            parent.addSubview(child)
        }
        panel.contentView = container

        panel.onCancel = { [weak self] in
            self?.hide()
        }
        panel.delegate = self
    }

    func showBelowStatusItem(_ button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        let frame = buttonWindow.frame
        let topLeft = NSPoint(x: frame.midX - PanelMetrics.width / 2, y: frame.minY)
        show(topLeft: topLeft, on: buttonWindow.screen)
    }

    func toggleBelowStatusItem(_ button: NSStatusBarButton) {
        if panel.isVisible {
            hide()
            return
        }
        // If the panel lost key status (and hid) because of this very click,
        // this is a dismiss, not an open request.
        guard Date().timeIntervalSince(lastHiddenAt) > 0.3 else { return }
        showBelowStatusItem(button)
    }

    func showAtCursor() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        show(topLeft: mouse, on: screen)
    }

    func hide() {
        guard panel.isVisible else { return }
        lastHiddenAt = Date()
        panel.orderOut(nil)
    }

    private func show(topLeft: NSPoint, on screen: NSScreen?) {
        autoTyper.capturePreviousApp()
        let browserURL = BrowserURLReader.activeTabURL(of: NSWorkspace.shared.frontmostApplication)
        let size = CGSize(width: PanelMetrics.width, height: PanelMetrics.height)
        let point = screen.map { PanelPlacement.clampedTopLeft(topLeft, size: size, in: $0.visibleFrame) } ?? topLeft
        panel.setFrameTopLeftPoint(point)
        // Activating (invisible for an accessory app — it owns no menu bar)
        // keeps text-field focus and secure input reliable.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        // After ordering front: the first prefill of a session may block on
        // the Public Suffix List still parsing, and that must not delay the
        // panel appearing.
        session.prefillKey(from: [browserURL, NSPasteboard.general.string(forType: .string)])
        session.requestFocus()
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
