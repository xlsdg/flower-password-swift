import AppKit

import FlowerPasswordCore

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let panel: FloatingPanel
    private let state: AppState
    private let delivery: PasswordDelivery

    /// Set every time the panel hides, used internally to distinguish
    /// "just hid due to focus loss from this very click" from a fresh toggle.
    private var lastHiddenAt = Date.distantPast

    init(state: AppState, delivery: PasswordDelivery) {
        self.state = state
        self.delivery = delivery
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

        let formView = PanelFormView(state: state, actions: actions)
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
        delivery.capturePreviousApp()
        let browserURL = BrowserURLReader.activeTabURL(of: NSWorkspace.shared.frontmostApplication)
        var point = topLeft
        if let visible = screen?.visibleFrame {
            // Push inside the right/bottom edges first; the left/top clamps
            // run last so they win when the work area is too small.
            point.x = min(point.x, visible.maxX - PanelMetrics.width)
            point.y = max(point.y, visible.minY + PanelMetrics.height)
            point.x = max(point.x, visible.minX)
            point.y = min(point.y, visible.maxY)
        }
        panel.setFrameTopLeftPoint(point)
        // Activating (invisible for an accessory app — it owns no menu bar)
        // keeps text-field focus and secure input reliable.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        // After ordering front: the first prefill of a session may block on
        // the Public Suffix List still parsing, and that must not delay the
        // panel appearing.
        prefillKey(browserURL: browserURL)
        state.requestFocus()
    }

    /// On every show, the first absolute URL (frontmost browser tab, then
    /// clipboard) whose host has a recognized public suffix replaces the
    /// distinction code with its registrable label ("google" from
    /// www.google.co.uk).
    private func prefillKey(browserURL: String?) {
        let candidates = [browserURL, NSPasteboard.general.string(forType: .string)]
        guard
            let label = candidates.lazy.compactMap({ $0 }).compactMap({
                PublicSuffix.shared.registrableLabel(fromURLText: $0)
            }).first,
            label != state.key
        else { return }
        state.key = label
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
