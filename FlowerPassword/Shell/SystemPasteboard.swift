import AppKit

import FlowerPasswordDomain

final class SystemPasteboard: ClipboardStore {
    /// Marks the copied password as concealed (nspasteboard.org convention),
    /// so cooperating clipboard managers keep it out of their history.
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    private let pasteboard = NSPasteboard.general

    var changeCount: Int { pasteboard.changeCount }

    func replaceWithConcealedText(_ text: String) -> Int {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        pasteboard.setString("", forType: Self.concealedType)
        return pasteboard.changeCount
    }

    func clear() {
        pasteboard.clearContents()
    }
}
