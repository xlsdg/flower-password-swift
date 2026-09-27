import Foundation

public struct Release: Decodable, Equatable, Sendable {
    public let tagName: String
    public let htmlUrl: String
    public let assets: [Asset]

    public init(tagName: String, htmlUrl: String, assets: [Asset]) {
        self.tagName = tagName
        self.htmlUrl = htmlUrl
        self.assets = assets
    }

    public struct Asset: Decodable, Equatable, Sendable {
        public let name: String
        public let browserDownloadUrl: String

        public init(name: String, browserDownloadUrl: String) {
            self.name = name
            self.browserDownloadUrl = browserDownloadUrl
        }
    }

    public var normalizedVersion: String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }

    public var pageURL: URL {
        URL(string: htmlUrl) ?? URL(string: "https://github.com/xlsdg/flower-password-swift/releases")!
    }
}

public enum ReleaseDecision: Equatable, Sendable {
    case upToDate
    case installable(archiveURL: URL, signatureURL: URL)
    case manualOnly

    public static func decide(currentVersion: String, release: Release) -> ReleaseDecision {
        let latestVersion = release.normalizedVersion

        // Numeric comparison handles multi-digit components correctly:
        // "1.2.10" > "1.2.9".
        guard latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending else {
            return .upToDate
        }

        // The archive name contract with scripts/release.sh: the zip is named
        // "FlowerPassword-{version}.zip", the signature is "{zip}.sig", and
        // only HTTPS URLs are safe for automatic installation.
        let expectedArchiveName = "FlowerPassword-\(latestVersion).zip"
        guard
            let zipAsset = release.assets.first(where: { $0.name == expectedArchiveName }),
            let signatureAsset = release.assets.first(where: { $0.name == expectedArchiveName + ".sig" }),
            let zipURL = URL(string: zipAsset.browserDownloadUrl), zipURL.scheme == "https",
            let signatureURL = URL(string: signatureAsset.browserDownloadUrl), signatureURL.scheme == "https"
        else {
            return .manualOnly
        }

        return .installable(archiveURL: zipURL, signatureURL: signatureURL)
    }
}
