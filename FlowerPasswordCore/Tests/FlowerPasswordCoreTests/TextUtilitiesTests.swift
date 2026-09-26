import Testing

@testable import FlowerPasswordCore

@Suite("TextUtilities")
struct TextUtilitiesTests {
    @Test("keys the algorithm by prefix + key + suffix")
    func composition() throws {
        let expected = try FlowerPassword.code(password: "test", key: "pre-github-suf", length: 16)
        #expect(
            TextUtilities.generatedCode(
                password: "test", key: "github", prefix: "pre-", suffix: "-suf", length: 16) == expected)
        #expect(
            TextUtilities.generatedCode(
                password: "test", key: "pre-", prefix: "github", suffix: "-suf", length: 16) != expected)
    }

    @Test("is empty until both inputs are filled or when the length is invalid")
    func emptyCases() {
        #expect(TextUtilities.generatedCode(password: "", key: "k", prefix: "a", suffix: "b", length: 16) == "")
        #expect(TextUtilities.generatedCode(password: "p", key: "", prefix: "a", suffix: "b", length: 16) == "")
        #expect(TextUtilities.generatedCode(password: "p", key: "k", prefix: "", suffix: "", length: 99) == "")
    }

    @Test("masks all but the outer characters of longer passwords")
    func masking() {
        #expect(TextUtilities.maskPassword("") == "")
        #expect(TextUtilities.maskPassword("ab") == "••")
        #expect(TextUtilities.maskPassword("abcd") == "••••")
        #expect(TextUtilities.maskPassword("abcde") == "ab•de")
        #expect(TextUtilities.maskPassword("K3A2a66Bf88b628c") == "K3••••••••••••8c")
    }
}
