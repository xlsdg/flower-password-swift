import AppKit

/// Pasteboard writer that clears the copied password after 10 seconds. It
/// compares NSPasteboard.changeCount instead of re-reading the text: if
/// anything else was copied in the meantime the count moved on and the
/// pasteboard is left alone, without ever reading other apps' clipboard data.
@MainActor
final class ClipboardService {
    static let clearDelay: TimeInterval = 10

    /// Marks the copied password as concealed (nspasteboard.org convention),
    /// so cooperating clipboard managers keep it out of their history.
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    private var pendingClear: Task<Void, Never>?
    private var ownedChangeCount = -1

    func copy(_ text: String) {
        pendingClear?.cancel()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        pasteboard.setString("", forType: Self.concealedType)
        ownedChangeCount = pasteboard.changeCount

        pendingClear = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.clearDelay))
            guard !Task.isCancelled else { return }
            self?.clearIfStillOwned()
        }
    }

    /// Immediately runs the pending clear, if any. The scheduled task
    /// dies with the process, so termination paths (quit, the in-place
    /// update relaunch) call this to keep the 10-second promise.
    func clearIfOwned() {
        pendingClear?.cancel()
        pendingClear = nil
        clearIfStillOwned()
    }

    private func clearIfStillOwned() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount == ownedChangeCount else { return }
        pasteboard.clearContents()
    }
}
