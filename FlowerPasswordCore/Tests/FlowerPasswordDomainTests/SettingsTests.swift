import Foundation
import Testing

@testable import FlowerPasswordDomain

@MainActor
@Suite("Settings")
struct SettingsTests {
    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        return defaults
    }

    @Test("falls back to defaults when nothing is stored")
    func emptyStore() {
        let settings = Settings(defaults: makeDefaults())
        #expect(settings.prefix == "")
        #expect(settings.suffix == "")
        #expect(settings.passwordLength == PasswordLength.default)
        #expect(settings.theme == .auto)
        #expect(settings.shortcut == .commandOptionS)
        #expect(settings.autoType == false)
    }

    @Test("rejects stored values outside the supported set")
    func invalidStoredValues() {
        let defaults = makeDefaults()
        defaults.set(3, forKey: "passwordLength")
        defaults.set("sepia", forKey: "theme")
        defaults.set("cmd+x", forKey: "globalShortcut")
        let settings = Settings(defaults: defaults)
        #expect(settings.passwordLength == PasswordLength.default)
        #expect(settings.theme == .auto)
        #expect(settings.shortcut == .commandOptionS)
    }

    @Test("writes every change through and reloads it")
    func roundTrip() {
        let defaults = makeDefaults()
        let settings = Settings(defaults: defaults)
        settings.prefix = "a-"
        settings.suffix = "-z"
        settings.passwordLength = 24
        settings.theme = .dark
        settings.shortcut = .commandShiftF
        settings.autoType = true

        let reloaded = Settings(defaults: defaults)
        #expect(reloaded.prefix == "a-")
        #expect(reloaded.suffix == "-z")
        #expect(reloaded.passwordLength == 24)
        #expect(reloaded.theme == .dark)
        #expect(reloaded.shortcut == .commandShiftF)
        #expect(reloaded.autoType == true)
    }

    @Test("persists the stored keys the app has always used")
    func storageKeys() {
        let defaults = makeDefaults()
        let settings = Settings(defaults: defaults)
        settings.shortcut = .commandShiftP
        #expect(defaults.string(forKey: "globalShortcut") == "cmd+shift+p")
    }
}
