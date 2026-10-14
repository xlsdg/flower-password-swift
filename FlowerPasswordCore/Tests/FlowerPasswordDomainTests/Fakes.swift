import Foundation

@testable import FlowerPasswordDomain

@MainActor
final class FakePasteboard: Pasteboard {
    private(set) var changeCount = 0
    private(set) var text: String?

    func replaceWithConcealedText(_ text: String) -> Int {
        self.text = text
        changeCount += 1
        return changeCount
    }

    func clear() {
        text = nil
        changeCount += 1
    }

    /// Another app copying something.
    func externalCopy(_ text: String) {
        self.text = text
        changeCount += 1
    }
}

@MainActor
final class FakeClipboard: Clipboard {
    private(set) var copied: [String] = []
    func copy(_ text: String) { copied.append(text) }
}

@MainActor
final class FakeTyper: AutoTyper {
    var trusted = true
    /// When false the typed text is not delivered and the fallback runs.
    var delivers = true
    private(set) var promptedChecks = 0
    private(set) var typed: [String] = []

    func isTrusted(prompt: Bool) -> Bool {
        if prompt { promptedChecks += 1 }
        return trusted
    }

    func type(_ text: String, fallback: @escaping @MainActor () -> Void) {
        if delivers { typed.append(text) } else { fallback() }
    }
}

@MainActor
final class FakeNotifier: DeliveryNotifier {
    private(set) var copiedCount = 0
    private(set) var permissionRequests = 0
    func passwordCopied() { copiedCount += 1 }
    func autoTypeNeedsPermission() { permissionRequests += 1 }
}

@MainActor
final class FakeRegistry: HotkeyRegistering {
    /// Shortcuts the system refuses.
    var refused: Set<ShortcutOption> = []
    private(set) var registered: [ShortcutOption] = []

    func register(_ shortcut: ShortcutOption) -> Bool {
        registered.append(shortcut)
        return !refused.contains(shortcut)
    }
}

@MainActor
func makeSettings() -> Settings {
    Settings(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
}
