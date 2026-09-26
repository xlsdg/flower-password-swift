import AppKit

/// Reports focus gain the moment the field becomes first responder (the
/// delegate's `controlTextDidEndEditing` covers focus loss).
final class FocusReportingTextField: NSTextField {
    var onFocus: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocus?() }
        return accepted
    }
}

final class FocusReportingSecureTextField: NSSecureTextField {
    var onFocus: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocus?() }
        return accepted
    }
}

/// Borderless button with a layer-painted background. The default focus ring
/// traces only the title text; this one traces the full background shape.
class PanelButton: NSButton {
    override var focusRingMaskBounds: NSRect { bounds }

    override func drawFocusRingMask() {
        let radius = layer?.cornerRadius ?? 0
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()
        // Only left/right corner masks are used, so squaring off a whole half
        // matches the joined edge of the generate/length pair.
        let corners = layer?.maskedCorners ?? []
        let (left, right) = bounds.divided(atDistance: bounds.width / 2, from: .minXEdge)
        if !corners.contains(.layerMinXMinYCorner) { left.fill() }
        if !corners.contains(.layerMaxXMinYCorner) { right.fill() }
    }
}

/// Link-styled button: unlike a link inside a text view it is reachable with
/// Tab, activates with Space, and gives VoiceOver a readable name.
final class LinkButton: PanelButton {
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

/// Borderless button that reports mouse hover, for the hover-to-reveal
/// generated code and the hover background tint.
final class HoverButton: PanelButton {
    var onHover: ((Bool) -> Void)?
    private var hoverArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(
            rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHover?(false)
    }
}
