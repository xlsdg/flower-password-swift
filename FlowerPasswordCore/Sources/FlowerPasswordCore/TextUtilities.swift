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

    /// Compares two dotted version strings numerically, ignoring a leading
    /// "v" and treating missing components as zero ("1.0.10" > "1.0.9",
    /// "1.2" == "1.2.0").
    public static func compareVersions(_ lhs: String, _ rhs: String) -> Int {
        func parts(_ version: String) -> [Int] {
            var trimmed = version
            if trimmed.hasPrefix("v") {
                trimmed.removeFirst()
            }
            return trimmed.components(separatedBy: ".").map { Int($0) ?? 0 }
        }

        let left = parts(lhs)
        let right = parts(rhs)
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r {
                return l > r ? 1 : -1
            }
        }
        return 0
    }
}
