import Foundation

/// Copies a password and clears it after `clearDelay`. It compares the
/// pasteboard's change count instead of re-reading the text: if anything else
/// was copied in the meantime the count moved on and the pasteboard is left
/// alone, without ever reading other apps' clipboard data.
@MainActor
public final class ClipboardGuard: Clipboard {
    public static let defaultClearDelay: Duration = .seconds(10)

    private let pasteboard: Pasteboard
    private let clearDelay: Duration
    private var pendingClear: Task<Void, Never>?
    private var ownedChangeCount = -1

    public init(pasteboard: Pasteboard, clearDelay: Duration = ClipboardGuard.defaultClearDelay) {
        self.pasteboard = pasteboard
        self.clearDelay = clearDelay
    }

    public func copy(_ text: String) {
        pendingClear?.cancel()
        ownedChangeCount = pasteboard.replaceWithConcealedText(text)
        pendingClear = Task { [weak self, clearDelay] in
            try? await Task.sleep(for: clearDelay)
            guard !Task.isCancelled else { return }
            self?.clearIfStillOwned()
        }
    }

    /// Runs the pending clear now. The scheduled task dies with the process,
    /// so termination calls this to keep the promise.
    public func clearIfOwned() {
        pendingClear?.cancel()
        pendingClear = nil
        clearIfStillOwned()
    }

    private func clearIfStillOwned() {
        guard pasteboard.changeCount == ownedChangeCount else { return }
        pasteboard.clear()
    }
}
