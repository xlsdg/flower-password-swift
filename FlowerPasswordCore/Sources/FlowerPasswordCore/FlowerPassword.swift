import CryptoKit
import Foundation

/// The Flower Password derivation algorithm (https://flowerpassword.com):
/// the output must match the published algorithm byte for byte — every
/// generated password a user relies on depends on it. Equivalence is
/// enforced by the golden-vector fixture cross-checked against the
/// reference implementation.
public enum FlowerPassword {
    public enum LengthError: Error, Equatable {
        case outOfRange(Int)
    }

    public static let minLength = 2
    public static let maxLength = 32

    /// Character transformation rules are keyed off this string; it is part
    /// of the Flower Password algorithm specification.
    private static let magicString = "sunlovesnow1990090127xykab"

    /// Derives the site password from the memory password and distinction code.
    /// - Throws: `LengthError.outOfRange` if `length` is not within 2...32.
    public static func code(password: String, key: String, length: Int = 16) throws -> String {
        guard (minLength...maxLength).contains(length) else {
            throw LengthError.outOfRange(length)
        }

        let baseHash = hmacMD5Hex(message: password, key: key)
        let ruleChars = Array(hmacMD5Hex(message: baseHash, key: "kise"))
        var sourceChars = Array(hmacMD5Hex(message: baseHash, key: "snow"))

        // Uppercase source letters wherever the rule character appears in the
        // magic string; digits in the source pass through untouched.
        for index in sourceChars.indices where !sourceChars[index].isNumber {
            if magicString.contains(ruleChars[index]) {
                sourceChars[index] = Character(sourceChars[index].uppercased())
            }
        }

        // The first character must be a letter; a digit is replaced by "K".
        let first = sourceChars[0].isNumber ? "K" : String(sourceChars[0])
        return first + String(sourceChars[1..<length])
    }

    private static func hmacMD5Hex(message: String, key: String) -> String {
        let mac = HMAC<Insecure.MD5>.authenticationCode(
            for: Data(message.utf8),
            using: SymmetricKey(data: Data(key.utf8))
        )
        return mac.map { String(format: "%02x", $0) }.joined()
    }
}
