/// System boundaries the Domain orchestrates. The app target supplies the
/// AppKit-backed implementations; tests supply fakes.

@MainActor
public protocol Pasteboard: AnyObject {
    var changeCount: Int { get }
    /// Replaces the contents with a concealed text item and returns the new change count.
    func replaceWithConcealedText(_ text: String) -> Int
    func clear()
}

@MainActor
public protocol Clipboard: AnyObject {
    func copy(_ text: String)
}

@MainActor
public protocol AutoTyper: AnyObject {
    func isTrusted(prompt: Bool) -> Bool
    /// Types into the app that had focus before the panel opened, or calls `fallback`.
    func type(_ text: String, fallback: @escaping @MainActor () -> Void)
}

@MainActor
public protocol DeliveryNotifier: AnyObject {
    func passwordCopied()
    func autoTypeNeedsPermission()
}

@MainActor
public protocol HotkeyRegistering: AnyObject {
    /// Returns false when the system refuses the shortcut (typically already taken).
    func register(_ shortcut: ShortcutOption) -> Bool
}
