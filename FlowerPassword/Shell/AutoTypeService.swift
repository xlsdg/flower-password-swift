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

    /// Call before the panel takes focus, so the app that had it can be
    /// reactivated later. Ignores the app itself (e.g. re-entrant shows).
    func capturePreviousApp() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
            frontmost != NSRunningApplication.current
        else { return }
        previousApp = frontmost
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
    func type(_ text: String) {
        guard let app = previousApp, !text.isEmpty else { return }
        app.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.activationDelay) {
            Self.postKeystrokes(for: text)
        }
    }

    private static func postKeystrokes(for text: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let units = Array(text.utf16)
        for chunkStart in stride(from: 0, to: units.count, by: chunkSize) {
            let chunk = Array(units[chunkStart..<min(chunkStart + chunkSize, units.count)])
            post(chunk, source: source)
        }
    }

    private static func post(_ chunk: [UInt16], source: CGEventSource?) {
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else { return }
        keyDown.flags = []
        keyUp.flags = []
        keyDown.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
        keyUp.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
