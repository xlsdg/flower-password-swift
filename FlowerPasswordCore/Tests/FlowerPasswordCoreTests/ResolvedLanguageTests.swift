import Testing

@testable import FlowerPasswordCore

@Suite("ResolvedLanguage")
struct ResolvedLanguageTests {
    @Test("maps Traditional-Chinese locales to zh-TW")
    func traditional() {
        #expect(ResolvedLanguage.detect(from: "zh-Hant") == .zhTW)
        #expect(ResolvedLanguage.detect(from: "zh-Hant-CN") == .zhTW)
        #expect(ResolvedLanguage.detect(from: "zh-TW") == .zhTW)
        #expect(ResolvedLanguage.detect(from: "zh_TW") == .zhTW)
        #expect(ResolvedLanguage.detect(from: "zh-HK") == .zhTW)
        #expect(ResolvedLanguage.detect(from: "zh-MO") == .zhTW)
    }

    @Test("maps other Chinese locales to zh-CN")
    func simplified() {
        #expect(ResolvedLanguage.detect(from: "zh") == .zhCN)
        #expect(ResolvedLanguage.detect(from: "zh-CN") == .zhCN)
        #expect(ResolvedLanguage.detect(from: "zh-Hans") == .zhCN)
        #expect(ResolvedLanguage.detect(from: "zh-Hans-SG") == .zhCN)
    }

    @Test("maps everything else to en-US")
    func fallback() {
        #expect(ResolvedLanguage.detect(from: "en") == .enUS)
        #expect(ResolvedLanguage.detect(from: "en-US") == .enUS)
        #expect(ResolvedLanguage.detect(from: "ja-JP") == .enUS)
        #expect(ResolvedLanguage.detect(from: nil) == .enUS)
        #expect(ResolvedLanguage.detect(from: "") == .enUS)
    }
}
