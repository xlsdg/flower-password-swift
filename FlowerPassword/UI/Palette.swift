import AppKit

/// Brand color tables for the light and dark themes.
struct Palette {
    let windowTint: NSColor
    let textPrimary: NSColor
    let textSecondary: NSColor
    let border: NSColor
    let inputBackground: NSColor
    let inputText: NSColor
    let buttonPrimary: NSColor
    let buttonPrimaryHover: NSColor
    let buttonText: NSColor
    let link: NSColor

    static func palette(for appearance: NSAppearance) -> Palette {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
    }

    static let light = Palette(
        windowTint: NSColor(hex: 0xFFFFFF, opacity: 0.72),
        textPrimary: NSColor(hex: 0x168BC3),
        textSecondary: NSColor(hex: 0x999999),
        border: NSColor(hex: 0xCCCCCC),
        inputBackground: NSColor(hex: 0xFFFFFF),
        inputText: NSColor(hex: 0x333333),
        buttonPrimary: NSColor(hex: 0x168BC3),
        buttonPrimaryHover: NSColor(hex: 0x057AB2),
        buttonText: NSColor(hex: 0xFFFFFF),
        link: NSColor(hex: 0x168BC3)
    )

    static let dark = Palette(
        windowTint: NSColor(hex: 0x1E1E1E, opacity: 0.72),
        textPrimary: NSColor(hex: 0x4DB8E8),
        textSecondary: NSColor(hex: 0xAAAAAA),
        border: NSColor(hex: 0x444444),
        inputBackground: NSColor(hex: 0x2D2D2D),
        inputText: NSColor(hex: 0xE0E0E0),
        buttonPrimary: NSColor(hex: 0x4DB8E8),
        buttonPrimaryHover: NSColor(hex: 0x3A9FD1),
        buttonText: NSColor(hex: 0x1E1E1E),
        link: NSColor(hex: 0x4DB8E8)
    )
}

extension NSColor {
    convenience init(hex: UInt32, opacity: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: opacity
        )
    }
}
