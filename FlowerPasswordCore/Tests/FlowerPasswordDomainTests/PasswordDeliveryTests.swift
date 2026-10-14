import Testing

@testable import FlowerPasswordDomain

@MainActor
@Suite("PasswordDelivery")
struct PasswordDeliveryTests {
    private let settings = makeSettings()
    private let clipboard = FakeClipboard()
    private let typer = FakeTyper()
    private let notifier = FakeNotifier()

    private func makeDelivery() -> PasswordDelivery {
        PasswordDelivery(settings: settings, clipboard: clipboard, typer: typer, notifier: notifier)
    }

    @Test("copies and announces when auto-type is off")
    func copiesByDefault() {
        makeDelivery().deliver("pw")
        #expect(clipboard.copied == ["pw"])
        #expect(typer.typed.isEmpty)
        #expect(notifier.copiedCount == 1)
    }

    @Test("types instead of copying when auto-type is on and trusted")
    func typesWhenTrusted() {
        settings.autoType = true
        makeDelivery().deliver("pw")
        #expect(typer.typed == ["pw"])
        #expect(clipboard.copied.isEmpty)
    }

    @Test("falls back to the clipboard once the system revokes trust")
    func revokedTrustCopies() {
        settings.autoType = true
        typer.trusted = false
        let delivery = makeDelivery()
        #expect(delivery.willAutoType == false)
        delivery.deliver("pw")
        #expect(clipboard.copied == ["pw"])
    }

    @Test("falls back to the clipboard when typing could not be delivered")
    func undeliveredTypingCopies() {
        settings.autoType = true
        typer.delivers = false
        makeDelivery().deliver("pw")
        #expect(clipboard.copied == ["pw"])
        #expect(notifier.copiedCount == 1)
    }

    @Test("toggling on without trust asks for permission and stays off")
    func toggleOnWithoutTrust() {
        typer.trusted = false
        let delivery = makeDelivery()
        delivery.toggleAutoType()
        #expect(typer.promptedChecks == 1)
        #expect(notifier.permissionRequests == 1)
        #expect(settings.autoType == false)
    }

    @Test("toggling on with trust enables auto-type")
    func toggleOnWithTrust() {
        makeDelivery().toggleAutoType()
        #expect(settings.autoType == true)
    }

    @Test("toggling off needs no permission")
    func toggleOff() {
        settings.autoType = true
        let delivery = makeDelivery()
        delivery.toggleAutoType()
        #expect(settings.autoType == false)
        #expect(typer.promptedChecks == 0)
    }

    @Test("a stored 'on' with revoked trust re-prompts instead of switching off")
    func staleOnRePrompts() {
        settings.autoType = true
        typer.trusted = false
        let delivery = makeDelivery()
        delivery.toggleAutoType()
        #expect(notifier.permissionRequests == 1)
        #expect(settings.autoType == true)
    }
}
