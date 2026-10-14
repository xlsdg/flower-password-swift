import Testing

@testable import FlowerPasswordDomain

@MainActor
@Suite("ClipboardGuard")
struct ClipboardGuardTests {
    private let delay = Duration.milliseconds(20)
    private let settle = Duration.milliseconds(300)

    @Test("clears the password after the delay")
    func clearsAfterDelay() async throws {
        let pasteboard = FakeClipboardStore()
        let guardian = ClipboardGuard(pasteboard: pasteboard, clearDelay: delay)
        guardian.copy("secret")
        #expect(pasteboard.text == "secret")
        try await Task.sleep(for: settle)
        #expect(pasteboard.text == nil)
    }

    @Test("leaves the pasteboard alone when something else was copied meanwhile")
    func respectsForeignCopy() async throws {
        let pasteboard = FakeClipboardStore()
        let guardian = ClipboardGuard(pasteboard: pasteboard, clearDelay: delay)
        guardian.copy("secret")
        pasteboard.externalCopy("user data")
        try await Task.sleep(for: settle)
        #expect(pasteboard.text == "user data")
    }

    @Test("a second copy restarts the countdown instead of clearing early")
    func recopyRestarts() async throws {
        let pasteboard = FakeClipboardStore()
        let guardian = ClipboardGuard(pasteboard: pasteboard, clearDelay: .milliseconds(150))
        guardian.copy("first")
        try await Task.sleep(for: .milliseconds(100))
        guardian.copy("second")
        try await Task.sleep(for: .milliseconds(100))
        #expect(pasteboard.text == "second")
        try await Task.sleep(for: settle)
        #expect(pasteboard.text == nil)
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
