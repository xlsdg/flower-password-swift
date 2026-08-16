import Foundation

/// A concrete UI language after resolving an automatic setting against the
/// system locale.
public enum ResolvedLanguage: Sendable {
    case zhCN
    case zhTW
    case enUS

    /// Traditional-Chinese locales map to zh-TW, any other Chinese to zh-CN,
    /// everything else to en-US. `maximalIdentifier` fills in the script
    /// subtag from ICU's likely-subtags data, so "zh-TW" resolves to Hant
    /// without a hand-maintained region table.
    public static func detect(from identifier: String?) -> ResolvedLanguage {
        guard let identifier else { return .enUS }
        let language = Locale.Language(identifier: identifier)
        guard language.languageCode == "zh" else { return .enUS }
        return Locale.Language(identifier: language.maximalIdentifier).script == "Hant" ? .zhTW : .zhCN
    }
}
