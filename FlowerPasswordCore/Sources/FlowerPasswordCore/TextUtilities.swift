import Foundation

/// Pure string helpers shared with the app layer, kept here so they are
/// covered by the package test suite.
public enum TextUtilities {
    /// Masks a generated password for display on the generate button:
    /// 4 characters or fewer become all bullets, longer values keep the
    /// first two and last two characters.
    public static func maskPassword(_ password: String) -> String {
        guard password.count > 4 else {
            return String(repeating: "•", count: password.count)
        }
        let start = password.prefix(2)
        let end = password.suffix(2)
        let middle = String(repeating: "•", count: password.count - 4)
        return "\(start)\(middle)\(end)"
    }
}
