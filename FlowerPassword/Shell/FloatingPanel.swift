import AppKit

enum PanelMetrics {
    static let width: CGFloat = 300
    static let height: CGFloat = 334
    static let cornerRadius: CGFloat = 12
    static var size: NSSize { NSSize(width: width, height: height) }
}

/// Borderless, non-activating floating panel hosting the SwiftUI form:
/// transparent with under-window vibrancy, always on top, and visible on
/// every Space including fullscreen ones.
final class FloatingPanel: NSPanel {
    var onCancel: (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: PanelMetrics.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
    }

    // Borderless windows refuse key status by default; the form needs it.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Esc dismisses the panel.
    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
