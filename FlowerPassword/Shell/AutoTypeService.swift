import AppKit
import ApplicationServices

/// Types a generated password directly into whatever text field had focus
/// before the panel opened, bypassing the clipboard entirely. Requires
/// Accessibility permission (CGEvent posting is silently ignored otherwise).
@MainActor
final class AutoTypeService {
    /// CGEvent's keyboardSetUnicodeString caps a single event's payload;
    /// long passwords are split into chunks of this size.
    private static let chunkSize = 20
    /// Gives the previously-frontmost app time to finish reactivating and
    /// restore keyboard focus before characters are injected.
    private static let activationDelay: TimeInterval = 0.15

    private var previousApp: NSRunningApplication?
    private var pendingType: Task<Void, Never>?

    /// Call before the panel takes focus, so the app that had it can be
    /// reactivated later. Ignores the app itself (e.g. re-entrant shows).
    func capturePreviousApp() {
        previousApp = NSWorkspace.shared.frontmostApplication
            .flatMap { $0 == NSRunningApplication.current ? nil : $0 }
    }

    /// Whether the process is trusted for Accessibility. Pass `prompt: true`
    /// to have the system show its own permission dialog when untrusted.
    static func isTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Reactivates the app that owned focus before the panel opened, then
    /// injects `text` as synthesized keystrokes once it's had time to
    /// restore that focus.
    @discardableResult
    func type(_ text: String, fallback: @escaping @MainActor () -> Void) -> Bool {
        guard let app = previousApp, !text.isEmpty else { return false }
        pendingType?.cancel()
        app.activate()
        pendingType = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.activationDelay))
            // A newer type() superseded this one; its own path decides delivery.
            if Task.isCancelled { return }
            guard app.isActive, NSWorkspace.shared.frontmostApplication == app else {
                fallback()
                return
            }
            if !Self.postKeystrokes(for: text) {
                fallback()
            }
            self?.pendingType = nil
        }
        return true
    }

    private static func postKeystrokes(for text: String) -> Bool {
        guard isTrusted(prompt: false) else { return false }
        let source = CGEventSource(stateID: .combinedSessionState)
        let units = Array(text.utf16)
        for chunkStart in stride(from: 0, to: units.count, by: chunkSize) {
            let chunk = Array(units[chunkStart..<min(chunkStart + chunkSize, units.count)])
            guard post(chunk, source: source) else { return false }
        }
        return true
    }

    private static func post(_ chunk: [UInt16], source: CGEventSource?) -> Bool {
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else { return false }
        keyDown.flags = []
        keyUp.flags = []
        keyDown.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
        keyUp.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
