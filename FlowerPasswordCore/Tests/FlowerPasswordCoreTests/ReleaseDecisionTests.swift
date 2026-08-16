import Testing
@testable import FlowerPasswordCore

@Suite("ReleaseDecision")
struct ReleaseDecisionTests {

    // MARK: - Version comparison

    @Test("returns upToDate when versions are equal")
    func versionsEqual() {
        let release = Release(
            tagName: "v1.2.3",
            htmlUrl: "https://github.com/example/repo/releases/tag/v1.2.3",
            assets: []
        )
        let decision = ReleaseDecision.decide(currentVersion: "1.2.3", release: release)
        #expect(decision == .upToDate)
    }

    @Test("returns upToDate when release is older")
    func releaseOlder() {
        let release = Release(
            tagName: "1.2.2",
            htmlUrl: "https://github.com/example/repo/releases/tag/1.2.2",
            assets: []
        )
        let decision = ReleaseDecision.decide(currentVersion: "1.2.3", release: release)
        #expect(decision == .upToDate)
    }

    @Test("handles tags with v prefix")
    func tagWithVPrefix() {
        let release = Release(
            tagName: "v1.2.4",
            htmlUrl: "https://github.com/example/repo/releases/tag/v1.2.4",
            assets: [
                Release.Asset(name: "FlowerPassword-1.2.4.zip", browserDownloadUrl: "https://example.com/app.zip"),
                Release.Asset(name: "FlowerPassword-1.2.4.zip.sig", browserDownloadUrl: "https://example.com/app.zip.sig")
            ]
        )
        let decision = ReleaseDecision.decide(currentVersion: "1.2.3", release: release)
        if case .installable = decision {
            // pass
        } else {
            Issue.record("Expected .installable, got \(decision)")
        }
    }

    @Test("compares multi-digit version components correctly")
    func multiDigitVersions() {
        let release = Release(
            tagName: "1.2.10",
            htmlUrl: "https://github.com/example/repo/releases/tag/1.2.10",
            assets: [
                Release.Asset(name: "FlowerPassword-1.2.10.zip", browserDownloadUrl: "https://example.com/app.zip"),
                Release.Asset(name: "FlowerPassword-1.2.10.zip.sig", browserDownloadUrl: "https://example.com/app.zip.sig")
            ]
        )
        let decision = ReleaseDecision.decide(currentVersion: "1.2.9", release: release)
        if case .installable = decision {
            // pass
        } else {
            Issue.record("Expected .installable, got \(decision)")
        }
    }

    @Test("detects major and minor version bumps")
    func majorMinorBumps() {
        let cases: [(current: String, tag: String)] = [
            ("1.2.3", "1.3.0"),
            ("1.2.3", "2.0.0")
        ]
        for (current, tag) in cases {
            let release = Release(
                tagName: tag,
                htmlUrl: "https://github.com/example/repo/releases/tag/\(tag)",
                assets: [
                    Release.Asset(name: "FlowerPassword-\(tag).zip", browserDownloadUrl: "https://example.com/app.zip"),
                    Release.Asset(name: "FlowerPassword-\(tag).zip.sig", browserDownloadUrl: "https://example.com/app.zip.sig")
                ]
            )
            let decision = ReleaseDecision.decide(currentVersion: current, release: release)
            if case .installable = decision {
                // pass
            } else {
                Issue.record("Expected .installable for \(current) → \(tag), got \(decision)")
            }
        }
    }

    // MARK: - Asset matching

    @Test("returns installable when both archive and signature are present")
    func assetPairPresent() {
        let release = Release(
            tagName: "1.2.4",
            htmlUrl: "https://github.com/example/repo/releases/tag/1.2.4",
            assets: [
                Release.Asset(name: "FlowerPassword-1.2.4.zip", browserDownloadUrl: "https://example.com/app.zip"),
                Release.Asset(name: "FlowerPassword-1.2.4.zip.sig", browserDownloadUrl: "https://example.com/app.zip.sig")
            ]
        )
        let decision = ReleaseDecision.decide(currentVersion: "1.2.3", release: release)
        guard case let .installable(archiveURL, signatureURL) = decision else {
            Issue.record("Expected .installable, got \(decision)")
            return
        }
        #expect(archiveURL.absoluteString == "https://example.com/app.zip")
        #expect(signatureURL.absoluteString == "https://example.com/app.zip.sig")
    }

    @Test("returns manualOnly when signature is missing")
    func signatureMissing() {
        let release = Release(
            tagName: "1.2.4",
            htmlUrl: "https://github.com/example/repo/releases/tag/1.2.4",
            assets: [
                Release.Asset(name: "FlowerPassword-1.2.4.zip", browserDownloadUrl: "https://example.com/app.zip")
            ]
        )
        let decision = ReleaseDecision.decide(currentVersion: "1.2.3", release: release)
        #expect(decision == .manualOnly)
    }

    @Test("pageURL uses htmlUrl, falling back to the releases page")
    func pageURL() {
        let release = Release(tagName: "1.2.4", htmlUrl: "https://github.com/example/repo/releases/tag/1.2.4", assets: [])
        #expect(release.pageURL.absoluteString == "https://github.com/example/repo/releases/tag/1.2.4")

        let broken = Release(tagName: "1.2.4", htmlUrl: "", assets: [])
        #expect(broken.pageURL.absoluteString == "https://github.com/xlsdg/flower-password-swift/releases")
    }

    @Test("returns manualOnly when archive name does not match")
    func archiveNameMismatch() {
        let release = Release(
            tagName: "1.2.4",
            htmlUrl: "https://github.com/example/repo/releases/tag/1.2.4",
            assets: [
                Release.Asset(name: "FlowerPassword-1.2.4-arm64.zip", browserDownloadUrl: "https://example.com/app.zip"),
                Release.Asset(name: "FlowerPassword-1.2.4-arm64.zip.sig", browserDownloadUrl: "https://example.com/app.zip.sig")
            ]
        )
        let decision = ReleaseDecision.decide(currentVersion: "1.2.3", release: release)
        #expect(decision == .manualOnly)
    }

    @Test("returns manualOnly when no assets are present")
    func noAssets() {
        let release = Release(
            tagName: "1.2.4",
            htmlUrl: "https://github.com/example/repo/releases/tag/1.2.4",
            assets: []
        )
        let decision = ReleaseDecision.decide(currentVersion: "1.2.3", release: release)
        #expect(decision == .manualOnly)
    }

    // MARK: - HTTPS requirement

    @Test("returns manualOnly when archive URL is HTTP")
    func archiveHTTP() {
        let release = Release(
            tagName: "1.2.4",
            htmlUrl: "https://github.com/example/repo/releases/tag/1.2.4",
            assets: [
                Release.Asset(name: "FlowerPassword-1.2.4.zip", browserDownloadUrl: "http://example.com/app.zip"),
                Release.Asset(name: "FlowerPassword-1.2.4.zip.sig", browserDownloadUrl: "https://example.com/app.zip.sig")
            ]
        )
        let decision = ReleaseDecision.decide(currentVersion: "1.2.3", release: release)
        #expect(decision == .manualOnly)
    }

    @Test("returns manualOnly when signature URL is HTTP")
    func signatureHTTP() {
        let release = Release(
            tagName: "1.2.4",
            htmlUrl: "https://github.com/example/repo/releases/tag/1.2.4",
            assets: [
                Release.Asset(name: "FlowerPassword-1.2.4.zip", browserDownloadUrl: "https://example.com/app.zip"),
                Release.Asset(name: "FlowerPassword-1.2.4.zip.sig", browserDownloadUrl: "http://example.com/app.zip.sig")
            ]
        )
        let decision = ReleaseDecision.decide(currentVersion: "1.2.3", release: release)
        #expect(decision == .manualOnly)
    }

    // MARK: - Integration

    @Test("real-world release fixture")
    func realWorldRelease() {
        let release = Release(
            tagName: "v1.2.3",
            htmlUrl: "https://github.com/xlsdg/flower-password-swift/releases/tag/v1.2.3",
            assets: [
                Release.Asset(
                    name: "FlowerPassword-1.2.3.zip",
                    browserDownloadUrl: "https://github.com/xlsdg/flower-password-swift/releases/download/v1.2.3/FlowerPassword-1.2.3.zip"
                ),
                Release.Asset(
                    name: "FlowerPassword-1.2.3.zip.sig",
                    browserDownloadUrl: "https://github.com/xlsdg/flower-password-swift/releases/download/v1.2.3/FlowerPassword-1.2.3.zip.sig"
                )
            ]
        )
        let decision = ReleaseDecision.decide(currentVersion: "1.2.2", release: release)
        guard case let .installable(archiveURL, signatureURL) = decision else {
            Issue.record("Expected .installable, got \(decision)")
            return
        }
        #expect(archiveURL.absoluteString.contains("FlowerPassword-1.2.3.zip"))
        #expect(signatureURL.absoluteString.contains("FlowerPassword-1.2.3.zip.sig"))
    }
}
