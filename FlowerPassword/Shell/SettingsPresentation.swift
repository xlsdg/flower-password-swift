import AppKit
import Carbon.HIToolbox

import FlowerPasswordDomain

extension ThemeMode {
    var title: String {
        switch self {
        case .light: String(localized: .themeLight)
        case .dark: String(localized: .themeDark)
        case .auto: String(localized: .themeAuto)
        }
    }

    /// A nil appearance follows the system; an explicit one pins every
    /// window (panel, alerts) to the chosen theme.
    @MainActor
    func apply() {
        switch self {
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        case .auto: NSApp.appearance = nil
        }
    }
}

extension ShortcutOption {
    /// (virtual key code, Carbon modifiers, menu display form like "⌘⌥S").
    private var spec: (key: Int, modifiers: Int, name: String) {
        switch self {
        case .commandOptionS: (kVK_ANSI_S, cmdKey | optionKey, "⌘⌥S")
        case .commandShiftS: (kVK_ANSI_S, cmdKey | shiftKey, "⌘⇧S")
        case .commandOptionP: (kVK_ANSI_P, cmdKey | optionKey, "⌘⌥P")
        case .commandShiftP: (kVK_ANSI_P, cmdKey | shiftKey, "⌘⇧P")
        case .commandOptionF: (kVK_ANSI_F, cmdKey | optionKey, "⌘⌥F")
        case .commandShiftF: (kVK_ANSI_F, cmdKey | shiftKey, "⌘⇧F")
        }
    }

    var keyCode: UInt32 { UInt32(spec.key) }
    var carbonModifiers: UInt32 { UInt32(spec.modifiers) }
    var displayName: String { spec.name }
}
