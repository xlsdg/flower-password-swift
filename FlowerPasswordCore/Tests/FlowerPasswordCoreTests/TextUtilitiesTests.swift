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

    @Test("compares versions numerically")
    func versionCompare() {
        #expect(TextUtilities.compareVersions("1.0.10", "1.0.9") == 1)
        #expect(TextUtilities.compareVersions("1.0.9", "1.0.10") == -1)
        #expect(TextUtilities.compareVersions("v1.2.3", "1.2.3") == 0)
        #expect(TextUtilities.compareVersions("1.2", "1.2.0") == 0)
        #expect(TextUtilities.compareVersions("2.0.0", "1.99.99") == 1)
        #expect(TextUtilities.compareVersions("1.10.0", "1.9.0") == 1)
    }
}
