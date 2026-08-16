import AppKit
import Foundation
import Observation

import FlowerPasswordCore

enum ThemeMode: String, CaseIterable {
    case light
    case dark
    case auto
}

enum LanguageMode: String, CaseIterable {
    case zhCN = "zh-CN"
    case zhTW = "zh-TW"
    case enUS = "en-US"
    case auto
}

/// All mutable app state, observed by the SwiftUI form and mutated by the
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
        static let language = "language"
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

    var language: LanguageMode {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
            l10n = .strings(for: Self.resolve(language))
        }
    }

    /// The UI strings for the effective language. Stored rather than derived:
    /// the form reads it dozens of times per body evaluation, and resolving
    /// `.auto` hits the system locale every time.
    private(set) var l10n: L10n

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
        let language = defaults.string(forKey: Keys.language).flatMap(LanguageMode.init) ?? .auto
        self.language = language
        shortcut = defaults.string(forKey: Keys.globalShortcut).flatMap(ShortcutOption.init) ?? .commandOptionS
        autoType = defaults.bool(forKey: Keys.autoType)
        l10n = .strings(for: Self.resolve(language))
    }

    /// `.auto` follows the system locale; the other cases are locale
    /// identifiers themselves, so one `detect` call covers all four.
    private static func resolve(_ mode: LanguageMode) -> ResolvedLanguage {
        .detect(from: mode == .auto ? Locale.preferredLanguages.first : mode.rawValue)
    }

    /// Empty while either input is empty, otherwise the flower password for
    /// (password, prefix + key + suffix, length). Cheap enough to recompute
    /// on every keystroke — three HMAC-MD5 of tiny inputs.
    var generatedCode: String {
        guard !password.isEmpty, !key.isEmpty else { return "" }
        let distinguishCode = prefix + key + suffix
        return (try? FlowerPassword.code(password: password, key: distinguishCode, length: passwordLength)) ?? ""
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
