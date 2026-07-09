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
            guard let self else { return }
            if NSPasteboard.general.changeCount == self.ownedChangeCount {
                NSPasteboard.general.clearContents()
            }
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
        if NSPasteboard.general.changeCount == ownedChangeCount {
            NSPasteboard.general.clearContents()
        }
    }
}
