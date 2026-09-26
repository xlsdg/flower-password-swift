import AppKit
import Foundation
import Observation

import FlowerPasswordCore

enum ThemeMode: String, CaseIterable {
    case auto
    case light
    case dark

    var title: String {
        switch self {
        case .light: String(localized: .themeLight)
        case .dark: String(localized: .themeDark)
        case .auto: String(localized: .themeAuto)
        }
    }
}

/// All mutable app state, observed by the panel form and mutated by the
/// AppKit shell (status item, panel, hotkey). Main-actor confined.
@MainActor
@Observable
final class AppState {
    enum FocusField: Hashable {
        case password
        case key
        case prefix
        case suffix
    }

    private enum Keys {
        static let prefix = "prefix"
        static let suffix = "suffix"
        static let passwordLength = "passwordLength"
        static let theme = "theme"
        static let globalShortcut = "globalShortcut"
        static let autoType = "autoType"
    }

    /// The memory password is deliberately never persisted anywhere.
    var password = ""
    var key = ""

    var prefix: String {
        didSet { defaults.set(prefix, forKey: Keys.prefix) }
    }

    var suffix: String {
        didSet { defaults.set(suffix, forKey: Keys.suffix) }
    }

    var passwordLength: Int {
        didSet { defaults.set(passwordLength, forKey: Keys.passwordLength) }
    }

    var theme: ThemeMode {
        didSet {
            defaults.set(theme.rawValue, forKey: Keys.theme)
            applyAppearance()
        }
    }

    var shortcut: ShortcutOption {
        didSet { defaults.set(shortcut.rawValue, forKey: Keys.globalShortcut) }
    }

    /// When enabled, the generated password is typed directly into the
    /// field that had focus before the panel opened, instead of being
    /// copied to the clipboard.
    var autoType: Bool {
        didSet { defaults.set(autoType, forKey: Keys.autoType) }
    }

    /// Bumped on every panel show; the form moves keyboard focus in response.
    private(set) var focusToken = 0

    /// Where the panel should put the caret when it appears.
    var focusField: FocusField { password.isEmpty ? .password : .key }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        prefix = defaults.string(forKey: Keys.prefix) ?? ""
        suffix = defaults.string(forKey: Keys.suffix) ?? ""
        let storedLength = defaults.integer(forKey: Keys.passwordLength)
        passwordLength = PasswordLength.range.contains(storedLength) ? storedLength : PasswordLength.default
        theme = defaults.string(forKey: Keys.theme).flatMap(ThemeMode.init) ?? .auto
        shortcut = defaults.string(forKey: Keys.globalShortcut).flatMap(ShortcutOption.init) ?? .commandOptionS
        autoType = defaults.bool(forKey: Keys.autoType)
    }

    /// Cheap enough to recompute on every keystroke — three HMAC-MD5 of tiny inputs.
    var generatedCode: String {
        TextUtilities.generatedCode(
            password: password, key: key, prefix: prefix, suffix: suffix, length: passwordLength)
    }

    func requestFocus() {
        focusToken += 1
    }

    /// A nil appearance follows the system; an explicit one pins every
    /// window (panel, alerts) to the chosen theme.
    func applyAppearance() {
        switch theme {
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        case .auto: NSApp.appearance = nil
        }
    }
}

/// UI limits for the generated password length; the algorithm itself
/// accepts 2...32, the form offers the practical 6...32.
enum PasswordLength {
    static let range = 6...32
    static let `default` = 16
}
