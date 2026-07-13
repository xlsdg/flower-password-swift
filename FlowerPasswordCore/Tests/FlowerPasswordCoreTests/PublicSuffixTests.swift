import Testing

@testable import FlowerPasswordCore

@Suite("PublicSuffix")
struct PublicSuffixTests {
    private let psl = PublicSuffix.shared

    @Test("extracts the registrable domain's leftmost label")
    func basics() {
        #expect(psl.secondLevelLabel(of: "github.com") == "github")
        #expect(psl.secondLevelLabel(of: "www.github.com") == "github")
        #expect(psl.secondLevelLabel(of: "gist.github.com") == "github")
        #expect(psl.secondLevelLabel(of: "www.bbc.co.uk") == "bbc")
        #expect(psl.secondLevelLabel(of: "foo.example.com.cn") == "example")
        #expect(psl.secondLevelLabel(of: "www.taobao.com") == "taobao")
    }

    @Test("honors wildcard and exception rules (kobe.jp)")
    func wildcardAndException() {
        // *.kobe.jp makes one extra label part of the suffix...
        #expect(psl.secondLevelLabel(of: "www.example.kobe.jp") == "www")
        // ...while !city.kobe.jp carves city back out as registrable.
        #expect(psl.secondLevelLabel(of: "www.city.kobe.jp") == "city")
        #expect(psl.secondLevelLabel(of: "city.kobe.jp") == "city")
    }

    @Test("includes the private-domains section of the list")
    func privateDomains() {
        #expect(psl.secondLevelLabel(of: "foo.github.io") == "foo")
        #expect(psl.secondLevelLabel(of: "bar.foo.github.io") == "foo")
    }

    @Test("normalizes case and trailing dots")
    func normalization() {
        #expect(psl.secondLevelLabel(of: "GitHub.COM") == "github")
        #expect(psl.secondLevelLabel(of: "github.com.") == "github")
    }

    @Test("rejects hosts without a listed suffix or that are a bare suffix")
    func rejections() {
        #expect(psl.secondLevelLabel(of: "com") == nil)
        #expect(psl.secondLevelLabel(of: "co.uk") == nil)
        #expect(psl.secondLevelLabel(of: "localhost") == nil)
        #expect(psl.secondLevelLabel(of: "192.168.1.1") == nil)
        #expect(psl.secondLevelLabel(of: "::1") == nil)
        #expect(psl.secondLevelLabel(of: "") == nil)
        #expect(psl.secondLevelLabel(of: "a..b.com") == nil)
        #expect(psl.secondLevelLabel(of: "foo.invalidtldxyz") == nil)
    }

    @Test("extracts the label from free text holding an absolute URL")
    func urlText() {
        #expect(psl.registrableLabel(fromURLText: "https://www.github.com/xlsdg") == "github")
        #expect(psl.registrableLabel(fromURLText: "  https://GitHub.COM/path?q=1 \n") == "github")
        #expect(psl.registrableLabel(fromURLText: "http://gist.github.io") == "gist")
    }

    @Test("rejects text that is not an absolute URL with a listed suffix")
    func urlTextRejections() {
        // No explicit scheme: a bare domain is not treated as a URL.
        #expect(psl.registrableLabel(fromURLText: "example.com") == nil)
        #expect(psl.registrableLabel(fromURLText: "") == nil)
        #expect(psl.registrableLabel(fromURLText: "hello world") == nil)
        #expect(psl.registrableLabel(fromURLText: "https://localhost/admin") == nil)
        #expect(psl.registrableLabel(fromURLText: "https://192.168.1.1/") == nil)
    }

    @Test("parses rules with comments and whitespace")
    func parsing() {
        let list = """
            // comment line
            com

            *.ck
            !www.ck
            """
        let custom = PublicSuffix(list: list)
        #expect(custom.secondLevelLabel(of: "example.com") == "example")
        #expect(custom.secondLevelLabel(of: "foo.anything.ck") == "foo")
        #expect(custom.secondLevelLabel(of: "www.ck") == "www")
        #expect(custom.secondLevelLabel(of: "example.org") == nil)
    }
}
