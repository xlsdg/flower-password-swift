import Foundation

/// Public Suffix List matcher used to prefill the distinction code from a
/// URL on the clipboard: hosts whose suffix is not in the list are rejected,
/// and the result is the registrable domain's leftmost label
/// ("www.github.com" → "github").
public struct PublicSuffix: Sendable {
    /// Parses the bundled list lazily on first access; parsing 16k rules
    /// takes a few milliseconds, so callers may warm this off the main thread.
    public static let shared = PublicSuffix()

    private let exactRules: Set<String>
    private let wildcardBases: Set<String>
    private let exceptionRules: Set<String>

    init() {
        let url = Bundle.module.url(forResource: "public_suffix_list", withExtension: "dat")
        let text = url.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        self.init(list: text)
    }

    init(list: String) {
        var exact = Set<String>()
        var wildcards = Set<String>()
        var exceptions = Set<String>()

        for line in list.split(whereSeparator: \.isNewline) {
            // A rule runs up to the first whitespace; comment lines start with "//".
            let rule = line.prefix(while: { !$0.isWhitespace })
            guard !rule.isEmpty, !rule.hasPrefix("//") else { continue }

            if rule.hasPrefix("!") {
                exceptions.insert(String(rule.dropFirst()))
            } else if rule.hasPrefix("*.") {
                wildcards.insert(String(rule.dropFirst(2)))
            } else {
                exact.insert(String(rule))
            }
        }

        exactRules = exact
        wildcardBases = wildcards
        exceptionRules = exceptions
    }

    /// Returns the registrable domain's leftmost label for a piece of free
    /// text (e.g. clipboard contents) holding an absolute URL, or nil
    /// otherwise. Only strings with an explicit scheme count as URLs; a
    /// bare "example.com" is rejected.
    public func registrableLabel(fromURLText text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
            components.scheme != nil,
            let host = components.host, !host.isEmpty,
            let label = secondLevelLabel(of: host), !label.isEmpty
        else { return nil }
        return label
    }

    /// Returns the registrable domain's leftmost label, or nil when the host
    /// has no listed public suffix, is itself a public suffix, or is not a
    /// well-formed domain name.
    public func secondLevelLabel(of host: String) -> String? {
        var normalized = host.lowercased()
        if normalized.hasSuffix(".") {
            normalized.removeLast()
        }
        guard !normalized.isEmpty, !normalized.contains(":") else { return nil }

        let labels = normalized.components(separatedBy: ".")
        guard labels.allSatisfy({ !$0.isEmpty }) else { return nil }

        // Scanning from the longest candidate suffix down; the first exact or
        // wildcard hit is therefore the prevailing (longest) rule. Exception
        // rules take priority over everything per the PSL specification.
        var matchStart: Int?
        var exceptionStart: Int?
        for start in labels.indices {
            let candidate = labels[start...].joined(separator: ".")
            if exceptionStart == nil, exceptionRules.contains(candidate) {
                exceptionStart = start
            }
            if matchStart == nil {
                if exactRules.contains(candidate) {
                    matchStart = start
                } else if start + 1 < labels.count,
                    wildcardBases.contains(labels[(start + 1)...].joined(separator: "."))
                {
                    matchStart = start
                }
            }
        }

        let suffixStart: Int
        if let exceptionStart {
            // An exception rule's public suffix is the rule minus its leftmost label.
            suffixStart = exceptionStart + 1
        } else if let matchStart {
            suffixStart = matchStart
        } else {
            return nil
        }

        guard suffixStart > 0 else { return nil }
        return labels[suffixStart - 1]
    }
}
