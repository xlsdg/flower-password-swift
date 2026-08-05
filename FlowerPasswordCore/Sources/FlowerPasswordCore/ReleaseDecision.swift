import Foundation

/// A release manifest decoded from the GitHub Releases API. Public so tests
/// and the Shell layer can construct fixtures and pass decoded API responses.
public struct Release: Codable, Equatable, Sendable {
    public let tagName: String
    public let htmlUrl: String
    public let assets: [Asset]

    public init(tagName: String, htmlUrl: String, assets: [Asset]) {
        self.tagName = tagName
        self.htmlUrl = htmlUrl
        self.assets = assets
    }

    public struct Asset: Codable, Equatable, Sendable {
        public let name: String
        public let browserDownloadUrl: String

        public init(name: String, browserDownloadUrl: String) {
            self.name = name
            self.browserDownloadUrl = browserDownloadUrl
        }
    }
}

/// The outcome of comparing the current version against a release: up to date,
/// an installable update is available, or an update exists but must be
/// downloaded manually.
public enum ReleaseDecision: Equatable, Sendable {
    case upToDate
    case installable(archiveURL: URL, signatureURL: URL)
    case manualOnly(pageURL: URL)

    /// Decides what to do with a release from the GitHub API. Returns
    /// `.upToDate` when the release is not newer than `currentVersion`,
    /// `.installable` when the release has a properly-named and signed archive
    /// with HTTPS URLs, or `.manualOnly` otherwise.
    ///
    /// - Parameters:
    ///   - currentVersion: The app's `CFBundleShortVersionString` at runtime.
    ///   - release: A successfully-decoded release manifest from the API.
    ///     Network failures should be handled before calling this function.
    public static func decide(currentVersion: String, release: Release) -> ReleaseDecision {
        // Strip the "v" prefix from the tag if present, so "v1.2.3" and
        // "1.2.3" both compare as "1.2.3".
        let latestVersion = release.tagName.hasPrefix("v")
            ? String(release.tagName.dropFirst())
            : release.tagName

        // Numeric comparison handles multi-digit components correctly:
        // "1.2.10" > "1.2.9".
        guard latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending else {
            return .upToDate
        }

        // The archive name contract with scripts/release.sh: the zip is named
        // "FlowerPassword-{version}.zip", and the signature is "{zip}.sig".
        let expectedArchiveName = "FlowerPassword-\(latestVersion).zip"
        guard
            let zipAsset = release.assets.first(where: { $0.name == expectedArchiveName }),
            let signatureAsset = release.assets.first(where: { $0.name == expectedArchiveName + ".sig" })
        else {
            // No matching pair found — fall back to manual download.
            guard let pageURL = URL(string: release.htmlUrl) else {
                return .manualOnly(pageURL: URL(string: "https://github.com")!)
            }
            return .manualOnly(pageURL: pageURL)
        }

        // Only HTTPS URLs are safe for automatic installation; anything else
        // (including http or malformed URLs) falls back to manual.
        guard
            let zipURL = URL(string: zipAsset.browserDownloadUrl),
            zipURL.scheme == "https",
            let signatureURL = URL(string: signatureAsset.browserDownloadUrl),
            signatureURL.scheme == "https"
        else {
            guard let pageURL = URL(string: release.htmlUrl) else {
                return .manualOnly(pageURL: URL(string: "https://github.com")!)
            }
            return .manualOnly(pageURL: pageURL)
        }

        return .installable(archiveURL: zipURL, signatureURL: signatureURL)
    }
}
