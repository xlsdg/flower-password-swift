import FlowerPasswordCore
import Observation

public enum FocusField: Hashable, Sendable {
    case password
    case key
    case prefix
    case suffix
}

/// In-memory panel input. Never persisted: the memory password must not reach disk.
@MainActor
@Observable
public final class Session {
    public var password = ""
    public var key = ""

    /// Bumped on every panel show; the form moves keyboard focus in response.
    public private(set) var focusToken = 0

    public init() {}

    /// Where the caret goes when the panel appears.
    public var focusField: FocusField { password.isEmpty ? .password : .key }

    public func requestFocus() {
        focusToken += 1
    }

    /// Replaces the distinction code with the registrable label of the first
    /// candidate URL ("google" from www.google.co.uk) whose host has a listed
    /// public suffix. Candidates are tried in order and nil entries skipped.
    public func prefillKey(from candidates: [String?], using suffixes: PublicSuffix = .shared) {
        guard
            let label = candidates.lazy.compactMap({ $0 }).compactMap({
                suffixes.registrableLabel(fromURLText: $0)
            }).first,
            label != key
        else { return }
        key = label
    }

    /// Cheap enough to recompute on every keystroke: three HMAC-MD5 over tiny inputs.
    public func generatedCode(using settings: Settings) -> String {
        TextUtilities.generatedCode(
            password: password, key: key, prefix: settings.prefix, suffix: settings.suffix,
            length: settings.passwordLength)
    }
}
