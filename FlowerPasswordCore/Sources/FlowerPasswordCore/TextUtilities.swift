import Foundation

public enum TextUtilities {
    /// The site password for the panel inputs: empty while the memory
    /// password or the distinction code is empty, otherwise the algorithm
    /// keyed by prefix + key + suffix in that order. Every stored password a
    /// user relies on depends on this composition.
    public static func generatedCode(
        password: String, key: String, prefix: String, suffix: String, length: Int
    ) -> String {
        guard !password.isEmpty, !key.isEmpty else { return "" }
        return (try? FlowerPassword.code(password: password, key: prefix + key + suffix, length: length)) ?? ""
    }

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
