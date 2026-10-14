import Foundation
import Observation

public enum ThemeMode: String, CaseIterable, Sendable {
    case auto
    case light
    case dark
}

/// Raw values are persisted; the key code and display form live in the app target.
public enum ShortcutOption: String, CaseIterable, Sendable {
    case commandOptionS = "cmd+opt+s"
    case commandShiftS = "cmd+shift+s"
    case commandOptionP = "cmd+opt+p"
    case commandShiftP = "cmd+shift+p"
    case commandOptionF = "cmd+opt+f"
    case commandShiftF = "cmd+shift+f"
}

/// The algorithm accepts 2...32; the form offers the practical 6...32.
public enum PasswordLength {
    public static let range = 6...32
    public static let `default` = 16
}

/// User preferences, persisted write-through to the injected defaults.
/// Nothing secret lives here: the memory password stays in `Session`.
@MainActor
@Observable
public final class Settings {
    private enum Keys {
        static let prefix = "prefix"
        static let suffix = "suffix"
        static let passwordLength = "passwordLength"
        static let theme = "theme"
        static let globalShortcut = "globalShortcut"
        static let autoType = "autoType"
    }

    public var prefix: String {
        didSet { defaults.set(prefix, forKey: Keys.prefix) }
    }

    public var suffix: String {
        didSet { defaults.set(suffix, forKey: Keys.suffix) }
    }

    public var passwordLength: Int {
        didSet { defaults.set(passwordLength, forKey: Keys.passwordLength) }
    }

    public var theme: ThemeMode {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }

    public var shortcut: ShortcutOption {
        didSet { defaults.set(shortcut.rawValue, forKey: Keys.globalShortcut) }
    }

    /// Type the password into the previously focused field instead of copying it.
    public var autoType: Bool {
        didSet { defaults.set(autoType, forKey: Keys.autoType) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        prefix = defaults.string(forKey: Keys.prefix) ?? ""
        suffix = defaults.string(forKey: Keys.suffix) ?? ""
        let storedLength = defaults.integer(forKey: Keys.passwordLength)
        passwordLength = PasswordLength.range.contains(storedLength) ? storedLength : PasswordLength.default
        theme = defaults.string(forKey: Keys.theme).flatMap(ThemeMode.init) ?? .auto
        shortcut = defaults.string(forKey: Keys.globalShortcut).flatMap(ShortcutOption.init) ?? .commandOptionS
        autoType = defaults.bool(forKey: Keys.autoType)
    }
}
