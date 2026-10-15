import Testing

@testable import FlowerPasswordDomain

@MainActor
@Suite("ClipboardGuard")
struct ClipboardGuardTests {
    @Test("clears the password after the delay")
    func clearsAfterDelay() async {
        let pasteboard = FakeClipboardStore()
        let guardian = ClipboardGuard(pasteboard: pasteboard, clearDelay: .zero)
        guardian.copy("secret")
        #expect(pasteboard.text == "secret")
        await guardian.pendingClear?.value
        #expect(pasteboard.text == nil)
    }

    @Test("leaves the pasteboard alone when something else was copied meanwhile")
    func respectsForeignCopy() async {
        let pasteboard = FakeClipboardStore()
        let guardian = ClipboardGuard(pasteboard: pasteboard, clearDelay: .zero)
        guardian.copy("secret")
        pasteboard.externalCopy("user data")
        await guardian.pendingClear?.value
        #expect(pasteboard.text == "user data")
    }

    @Test("a second copy cancels the first countdown instead of clearing early")
    func recopyRestarts() async throws {
        let pasteboard = FakeClipboardStore()
        let guardian = ClipboardGuard(pasteboard: pasteboard, clearDelay: .seconds(60))
        guardian.copy("first")
        let first = try #require(guardian.pendingClear)
        guardian.copy("second")
        await first.value
        #expect(first.isCancelled)
        #expect(pasteboard.text == "second")
        let second = try #require(guardian.pendingClear)
        #expect(second.isCancelled == false)
        guardian.clearIfOwned()
    }

    @Test("clearIfOwned clears immediately, as on quit")
    func clearOnQuit() {
        let pasteboard = FakeClipboardStore()
        let guardian = ClipboardGuard(pasteboard: pasteboard)
        guardian.copy("secret")
        guardian.clearIfOwned()
        #expect(pasteboard.text == nil)
    }

    @Test("clearIfOwned does not touch a foreign copy")
    func quitKeepsForeignCopy() {
        let pasteboard = FakeClipboardStore()
        let guardian = ClipboardGuard(pasteboard: pasteboard)
        guardian.copy("secret")
        pasteboard.externalCopy("user data")
        guardian.clearIfOwned()
        #expect(pasteboard.text == "user data")
    }
}
