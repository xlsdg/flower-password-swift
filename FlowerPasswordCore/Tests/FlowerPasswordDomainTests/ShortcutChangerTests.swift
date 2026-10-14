import Testing

@testable import FlowerPasswordDomain

@MainActor
@Suite("ShortcutChanger")
struct ShortcutChangerTests {
    private let settings = makeSettings()
    private let registry = FakeRegistry()
    private var failures: FailureLog

    @MainActor
    final class FailureLog {
        var shortcuts: [ShortcutOption] = []
    }

    init() {
        failures = FailureLog()
    }

    private func makeChanger() -> ShortcutChanger {
        let log = failures
        return ShortcutChanger(settings: settings, registry: registry) { log.shortcuts.append($0) }
    }

    @Test("persists a shortcut the system accepts")
    func accepted() {
        makeChanger().change(to: .commandShiftF)
        #expect(settings.shortcut == .commandShiftF)
        #expect(failures.shortcuts.isEmpty)
    }

    @Test("choosing the current shortcut does nothing")
    func unchanged() {
        makeChanger().change(to: settings.shortcut)
        #expect(registry.registered.isEmpty)
    }

    @Test("a refused shortcut is reported and the previous one is restored")
    func refusedRestoresPrevious() {
        registry.refused = [.commandShiftF]
        makeChanger().change(to: .commandShiftF)
        #expect(settings.shortcut == .commandOptionS)
        #expect(registry.registered == [.commandShiftF, .commandOptionS])
        #expect(failures.shortcuts == [.commandShiftF])
    }

    @Test("when the previous shortcut cannot be restored either, both failures are reported")
    func restoreFails() {
        registry.refused = [.commandShiftF, .commandOptionS]
        makeChanger().change(to: .commandShiftF)
        #expect(failures.shortcuts == [.commandShiftF, .commandOptionS])
    }

    @Test("registerCurrent reports a refused launch shortcut")
    func launchRefused() {
        registry.refused = [.commandOptionS]
        makeChanger().registerCurrent()
        #expect(failures.shortcuts == [.commandOptionS])
    }
}
