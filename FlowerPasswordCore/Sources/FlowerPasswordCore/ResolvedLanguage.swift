import Foundation

/// A concrete UI language after resolving an automatic setting against the
/// system locale.
public enum ResolvedLanguage: Sendable {
    case zhCN
    case zhTW
    case enUS

    /// Traditional-Chinese locales (the Hant script subtag, or the TW/HK/MO
    /// regions) map to zh-TW, any other Chinese to zh-CN, everything else
    /// to en-US.
    public static func detect(from identifier: String?) -> ResolvedLanguage {
        guard let identifier else { return .enUS }
        let locale = identifier.lowercased().replacingOccurrences(of: "_", with: "-")
        if locale.hasPrefix("zh") {
            if locale.contains("hant") || locale.hasPrefix("zh-tw") || locale.hasPrefix("zh-hk")
                || locale.hasPrefix("zh-mo")
            {
                return .zhTW
            }
            return .zhCN
        }
        return .enUS
    }
}
