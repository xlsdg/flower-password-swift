import Foundation
import Testing

import FlowerPasswordCore

@testable import FlowerPasswordDomain

@MainActor
@Suite("Session")
struct SessionTests {
    private func makeSettings() -> Settings {
        Settings(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
    }

    @Test("the caret starts in the password field until it is filled")
    func focusField() {
        let session = Session()
        #expect(session.focusField == .password)
        session.password = "secret"
        #expect(session.focusField == .key)
    }

    @Test("each focus request bumps the token")
    func focusToken() {
        let session = Session()
        let before = session.focusToken
        session.requestFocus()
        #expect(session.focusToken == before + 1)
    }

    @Test("the code follows the settings and stays empty until both inputs exist")
    func generatedCode() throws {
        let settings = makeSettings()
        settings.prefix = "pre-"
        settings.suffix = "-suf"
        settings.passwordLength = 12
        let session = Session()
        #expect(session.generatedCode(using: settings) == "")

        session.password = "test"
        session.key = "github"
        let expected = try FlowerPassword.code(password: "test", key: "pre-github-suf", length: 12)
        #expect(session.generatedCode(using: settings) == expected)
    }
}
