import AppKit

/// Pasteboard writer that clears the copied password after 10 seconds. It
/// compares NSPasteboard.changeCount instead of re-reading the text: if
/// anything else was copied in the meantime the count moved on and the
/// pasteboard is left alone, without ever reading other apps' clipboard data.
@MainActor
final class ClipboardService {
    static let clearDelay: TimeInterval = 10

    private var pendingClear: DispatchWorkItem?
    private var ownedChangeCount = -1

    func copy(_ text: String) {
        pendingClear?.cancel()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        ownedChangeCount = pasteboard.changeCount

        let work = DispatchWorkItem { [weak self] in
            self?.clearIfStillOwned()
        }
        pendingClear = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.clearDelay, execute: work)
    }

    /// Immediately runs the pending clear, if any. The scheduled work item
    /// dies with the process, so termination paths (quit, the in-place
    /// update relaunch) call this to keep the 10-second promise.
    func clearIfOwned() {
        pendingClear?.cancel()
        pendingClear = nil
        clearIfStillOwned()
    }

    /// Clears the pasteboard only while it still holds what this service
    /// last wrote — the single place that ownership rule lives.
    private func clearIfStillOwned() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount == ownedChangeCount else { return }
        pasteboard.clearContents()
    }
}
