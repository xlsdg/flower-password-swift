import Foundation
import Testing

@testable import FlowerPasswordCore

@Suite("ReleaseDecision")
struct ReleaseDecisionTests {
    /// An archive/signature asset pair following the release.sh naming
    /// contract for `version`, downloadable over HTTPS unless overridden.
    private func signedAssets(
        _ version: String,
        zipURL: String = "https://example.com/app.zip",
        signatureURL: String = "https://example.com/app.zip.sig"
    ) -> [Release.Asset] {
        [
            Release.Asset(name: "FlowerPassword-\(version).zip", browserDownloadUrl: zipURL),
            Release.Asset(name: "FlowerPassword-\(version).zip.sig", browserDownloadUrl: signatureURL),
        ]
    }

    private func makeRelease(tag: String, assets: [Release.Asset] = []) -> Release {
        Release(
            tagName: tag,
            htmlUrl: "https://github.com/example/repo/releases/tag/\(tag)",
            assets: assets
        )
    }

    /// The expected decision for a release carrying `signedAssets` with the
    /// default URLs.
    private let installable = ReleaseDecision.installable(
        archiveURL: URL(string: "https://example.com/app.zip")!,
        signatureURL: URL(string: "https://example.com/app.zip.sig")!
    )

    // MARK: - Version comparison

    @Test("returns upToDate when versions are equal")
    func versionsEqual() {
        let release = makeRelease(tag: "v1.2.3")
        #expect(ReleaseDecision.decide(currentVersion: "1.2.3", release: release) == .upToDate)
    }

    @Test("returns upToDate when release is older")
    func releaseOlder() {
        let release = makeRelease(tag: "1.2.2")
        #expect(ReleaseDecision.decide(currentVersion: "1.2.3", release: release) == .upToDate)
    }

    @Test("handles tags with v prefix")
    func tagWithVPrefix() {
        let release = makeRelease(tag: "v1.2.4", assets: signedAssets("1.2.4"))
        #expect(ReleaseDecision.decide(currentVersion: "1.2.3", release: release) == installable)
    }

    @Test("compares multi-digit version components correctly")
    func multiDigitVersions() {
        let release = makeRelease(tag: "1.2.10", assets: signedAssets("1.2.10"))
        #expect(ReleaseDecision.decide(currentVersion: "1.2.9", release: release) == installable)
    }

    @Test("detects major and minor version bumps", arguments: ["1.3.0", "2.0.0"])
    func majorMinorBumps(_ tag: String) {
        let release = makeRelease(tag: tag, assets: signedAssets(tag))
        #expect(ReleaseDecision.decide(currentVersion: "1.2.3", release: release) == installable)
    }

    // MARK: - Asset matching

    @Test("returns installable when both archive and signature are present")
    func assetPairPresent() {
        let release = makeRelease(tag: "1.2.4", assets: signedAssets("1.2.4"))
        #expect(ReleaseDecision.decide(currentVersion: "1.2.3", release: release) == installable)
    }

    @Test("returns manualOnly when signature is missing")
    func signatureMissing() {
        let release = makeRelease(tag: "1.2.4", assets: Array(signedAssets("1.2.4").dropLast()))
        #expect(ReleaseDecision.decide(currentVersion: "1.2.3", release: release) == .manualOnly)
    }

    @Test("returns manualOnly when archive name does not match")
    func archiveNameMismatch() {
        // Assets named for "1.2.4-arm64" do not match the plain "1.2.4" contract.
        let release = makeRelease(tag: "1.2.4", assets: signedAssets("1.2.4-arm64"))
        #expect(ReleaseDecision.decide(currentVersion: "1.2.3", release: release) == .manualOnly)
    }

    @Test("returns manualOnly when no assets are present")
    func noAssets() {
        let release = makeRelease(tag: "1.2.4")
        #expect(ReleaseDecision.decide(currentVersion: "1.2.3", release: release) == .manualOnly)
    }

    @Test("pageURL uses htmlUrl, falling back to the releases page")
    func pageURL() {
        let release = makeRelease(tag: "1.2.4")
        #expect(release.pageURL.absoluteString == "https://github.com/example/repo/releases/tag/1.2.4")

        let broken = Release(tagName: "1.2.4", htmlUrl: "", assets: [])
        #expect(broken.pageURL.absoluteString == "https://github.com/xlsdg/flower-password-swift/releases")
    }

    // MARK: - HTTPS requirement

    @Test("returns manualOnly when archive URL is HTTP")
    func archiveHTTP() {
        let release = makeRelease(
            tag: "1.2.4", assets: signedAssets("1.2.4", zipURL: "http://example.com/app.zip"))
        #expect(ReleaseDecision.decide(currentVersion: "1.2.3", release: release) == .manualOnly)
    }

    @Test("returns manualOnly when signature URL is HTTP")
    func signatureHTTP() {
        let release = makeRelease(
            tag: "1.2.4", assets: signedAssets("1.2.4", signatureURL: "http://example.com/app.zip.sig"))
        #expect(ReleaseDecision.decide(currentVersion: "1.2.3", release: release) == .manualOnly)
    }

    // MARK: - Integration

    @Test("real-world release fixture")
    func realWorldRelease() {
        let download = "https://github.com/xlsdg/flower-password-swift/releases/download/v1.2.3"
        let release = Release(
            tagName: "v1.2.3",
            htmlUrl: "https://github.com/xlsdg/flower-password-swift/releases/tag/v1.2.3",
            assets: signedAssets(
                "1.2.3",
                zipURL: "\(download)/FlowerPassword-1.2.3.zip",
                signatureURL: "\(download)/FlowerPassword-1.2.3.zip.sig"
            )
        )
        let expected = ReleaseDecision.installable(
            archiveURL: URL(string: "\(download)/FlowerPassword-1.2.3.zip")!,
            signatureURL: URL(string: "\(download)/FlowerPassword-1.2.3.zip.sig")!
        )
        #expect(ReleaseDecision.decide(currentVersion: "1.2.2", release: release) == expected)
    }
}
