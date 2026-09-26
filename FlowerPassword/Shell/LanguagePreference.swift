import Foundation

/// The UI language, stored as `AppleLanguages` in the app's own defaults
/// domain: the value System Settings › General › Language & Region ›
/// Applications writes, and the one `Bundle.main` resolves localizations
/// from at launch. A change therefore applies on the next launch.
///
/// Always `UserDefaults.standard`, even in UI tests: the bundle never reads
/// the injected suite.
enum LanguagePreference: CaseIterable {
    case system
    case english
    case simplifiedChinese
    case traditionalChinese

    private static let key = "AppleLanguages"

    /// Matches the localizations in Localizable.xcstrings.
    private var localization: String? {
        switch self {
        case .system: nil
        case .english: "en"
        case .simplifiedChinese: "zh-Hans"
        case .traditionalChinese: "zh-Hant"
        }
    }

    /// Language names are written in their own language, as in System Settings.
    var title: String {
        switch self {
        case .system: String(localized: .languageAuto)
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        }
    }

    /// Reads the app domain only: `UserDefaults.standard` would fall through
    /// to the global language list and hide whether a choice was made. A
    /// regional identifier written by System Settings (such as zh-Hant-HK)
    /// maps to the localization the bundle would pick for it.
    static var current: LanguagePreference {
        get {
            let domain = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
            guard let stored = (domain?[key] as? [String])?.first else { return .system }
            let localizations = allCases.compactMap(\.localization)
            let match = Bundle.preferredLocalizations(from: localizations, forPreferences: [stored]).first
            return allCases.first { $0.localization == match } ?? .system
        }
        set {
            if let localization = newValue.localization {
                UserDefaults.standard.set([localization], forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}
