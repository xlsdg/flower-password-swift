import AppKit

import FlowerPasswordCore

/// Owns the floating panel: builds the vibrancy + form view stack,
/// positions it below the status item or at the mouse cursor, and hides it
/// as soon as it stops being the key window.
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
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = PanelMetrics.cornerRadius
        effectView.layer?.cornerCurve = .continuous
        effectView.layer?.masksToBounds = true

        let formView = PanelFormView(state: state, actions: actions)
        formView.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(formView)
        NSLayoutConstraint.activate([
            formView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            formView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            formView.topAnchor.constraint(equalTo: effectView.topAnchor),
            formView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
        ])
        panel.contentView = effectView

        panel.onCancel = { [weak self] in
            self?.hide()
        }
        panel.delegate = self
    }

    /// Horizontally centered under the status item, flush with the bottom
    /// edge of the menu bar. Shows unconditionally, regardless of current
    /// visibility or recent dismissal.
    func showBelowStatusItem(_ button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        let frame = buttonWindow.frame
        let topLeft = NSPoint(x: frame.midX - PanelMetrics.width / 2, y: frame.minY)
        show(topLeft: topLeft, on: buttonWindow.screen)
    }

    /// Toggles the panel below the status item: hides if visible, shows if
    /// hidden. When the panel just hid because this click made it lose key
    /// status, the toggle is ignored (otherwise a single click would dismiss
    /// and immediately re-show).
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

    /// Top-left corner at the mouse cursor, clamped into the work area of
    /// the screen under the cursor.
    func showAtCursor() {
        let mouse = NSEvent.mouseLocation
        let screen =
            NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        show(topLeft: mouse, on: screen)
    }

    func hide() {
        guard panel.isVisible else { return }
        lastHiddenAt = Date()
        panel.orderOut(nil)
    }

    private func show(topLeft: NSPoint, on screen: NSScreen?) {
        delivery.capturePreviousApp()
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
        prefillKeyFromClipboard()
        state.requestFocus()
    }

    /// On every show, if the clipboard holds an absolute URL whose host has
    /// a recognized public suffix, the registrable label ("google" from
    /// www.google.co.uk) replaces the distinction code.
    private func prefillKeyFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string),
            let label = PublicSuffix.shared.registrableLabel(fromURLText: text),
            label != state.key
        else { return }
        state.key = label
    }

    /// The panel hides as soon as it stops being the key window.
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
