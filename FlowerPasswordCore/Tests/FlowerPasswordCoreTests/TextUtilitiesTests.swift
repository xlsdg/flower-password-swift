import Testing

@testable import FlowerPasswordCore

@Suite("TextUtilities")
struct TextUtilitiesTests {
    @Test("masks all but the outer characters of longer passwords")
    func masking() {
        #expect(TextUtilities.maskPassword("") == "")
        #expect(TextUtilities.maskPassword("ab") == "••")
        #expect(TextUtilities.maskPassword("abcd") == "••••")
        #expect(TextUtilities.maskPassword("abcde") == "ab•de")
        #expect(TextUtilities.maskPassword("K3A2a66Bf88b628c") == "K3••••••••••••8c")
    }
}
