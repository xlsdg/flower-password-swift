import AppKit
import SwiftUI

import FlowerPasswordCore

/// Owns the floating panel: builds the vibrancy + SwiftUI content stack,
/// positions it below the status item or at the mouse cursor, and hides it
/// as soon as it stops being the key window.
@MainActor
final class PanelController: NSObject {
    private let panel: FloatingPanel
    private let state: AppState
    private let clipboard: ClipboardService
    private let autoType: AutoTypeService

    /// Set every time the panel hides. The status item uses it to tell
    /// "hidden by this very click's focus loss" apart from a fresh open.
    private(set) var lastHiddenAt = Date.distantPast

    var isVisible: Bool { panel.isVisible }

    init(state: AppState, clipboard: ClipboardService, autoType: AutoTypeService) {
        self.state = state
        self.clipboard = clipboard
        self.autoType = autoType
        self.panel = FloatingPanel()
        super.init()

        let actions = PanelActions(
            copyAndHide: { [weak self] code in
                guard let self else { return }
                if self.state.autoType, AutoTypeService.isTrusted(prompt: false) {
                    self.hide()
                    self.autoType.type(code)
                } else {
                    self.clipboard.copy(code)
                    self.hide()
                }
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

        let hostingView = NSHostingView(rootView: ContentView(state: state, actions: actions))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: effectView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
        ])
        panel.contentView = effectView

        panel.onCancel = { [weak self] in
            self?.hide()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidResignKey(_:)),
            name: NSWindow.didResignKeyNotification,
            object: panel
        )
    }

    /// Horizontally centered under the status item, flush with the bottom
    /// edge of the menu bar.
    func showBelowStatusItem(_ button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        let frame = buttonWindow.frame
        let topLeft = NSPoint(x: frame.midX - PanelMetrics.width / 2, y: frame.minY)
        show(topLeft: topLeft, on: buttonWindow.screen)
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
        autoType.capturePreviousApp()
        prefillKeyFromClipboard()
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
        state.requestFocus()
    }

    @objc private func panelDidResignKey(_ notification: Notification) {
        hide()
    }

    /// On every show, if the clipboard holds an absolute URL whose host has
    /// a recognized public suffix, the registrable label ("google" from
    /// www.google.co.uk) replaces the distinction code. Only strings with an
    /// explicit scheme count as URLs; a bare "example.com" is ignored.
    private func prefillKeyFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
            components.scheme != nil,
            let host = components.host?.lowercased(), !host.isEmpty,
            let label = PublicSuffix.shared.secondLevelLabel(of: host), !label.isEmpty
        else { return }
        state.key = label
    }
}
