import SwiftUI

/// Brand color tables for the light and dark themes.
struct Palette {
    let windowTint: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let border: Color
    let inputBackground: Color
    let inputText: Color
    let buttonPrimary: Color
    let buttonPrimaryHover: Color
    let buttonText: Color
    let link: Color
    let linkHover: Color

    static func palette(for scheme: ColorScheme) -> Palette {
        scheme == .dark ? .dark : .light
    }

    static let light = Palette(
        windowTint: Color(hex: 0xFFFFFF, opacity: 0.72),
        textPrimary: Color(hex: 0x168BC3),
        textSecondary: Color(hex: 0x999999),
        textTertiary: Color(hex: 0x666666),
        border: Color(hex: 0xCCCCCC),
        inputBackground: Color(hex: 0xFFFFFF),
        inputText: Color(hex: 0x333333),
        buttonPrimary: Color(hex: 0x168BC3),
        buttonPrimaryHover: Color(hex: 0x057AB2),
        buttonText: Color(hex: 0xFFFFFF),
        link: Color(hex: 0x168BC3),
        linkHover: Color(hex: 0xFF881C)
    )

    static let dark = Palette(
        windowTint: Color(hex: 0x1E1E1E, opacity: 0.72),
        textPrimary: Color(hex: 0x4DB8E8),
        textSecondary: Color(hex: 0xAAAAAA),
        textTertiary: Color(hex: 0x999999),
        border: Color(hex: 0x444444),
        inputBackground: Color(hex: 0x2D2D2D),
        inputText: Color(hex: 0xE0E0E0),
        buttonPrimary: Color(hex: 0x4DB8E8),
        buttonPrimaryHover: Color(hex: 0x3A9FD1),
        buttonText: Color(hex: 0x1E1E1E),
        link: Color(hex: 0x4DB8E8),
        linkHover: Color(hex: 0xFFA84D)
    )
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
