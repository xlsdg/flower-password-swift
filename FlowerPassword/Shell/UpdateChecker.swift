import AppKit

/// Manual update check against the GitHub releases API: compare the latest
/// tag against the bundle version and, when the release carries a signed
/// archive, download, verify, install, and relaunch in place. Releases
/// without a signature fall back to opening the release page, as does any
/// install failure.
@MainActor
final class UpdateChecker {
    private let state: AppState
    private var isChecking = false

    private static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/xlsdg/flower-password-swift/releases/latest")!

    init(state: AppState) {
        self.state = state
    }

    func check() {
        guard !isChecking else { return }
        isChecking = true
        Task {
            defer { isChecking = false }
            let l10n = state.l10n
            do {
                let release = try await Self.fetchLatestRelease()
                let current = Self.currentVersion
                let latest =
                    release.tagName.hasPrefix("v")
                    ? String(release.tagName.dropFirst()) : release.tagName
                guard latest.compare(current, options: .numeric) == .orderedDescending else {
                    Dialogs.noUpdate(l10n, version: current)
                    return
                }
                if let update = Self.signedArchive(in: release, version: latest) {
                    guard Dialogs.updateAvailable(l10n, current: current, latest: latest) else {
                        return
                    }
                    do {
                        // On success install() relaunches and never returns.
                        try await SelfUpdater.install(
                            zipURL: update.archive,
                            signatureURL: update.signature,
                            expectedVersion: latest
                        )
                    } catch {
                        if Dialogs.updateInstallFailed(l10n, detail: error.localizedDescription) {
                            Self.openReleasePage(release)
                        }
                    }
                } else if Dialogs.updateAvailableManual(l10n, current: current, latest: latest) {
                    Self.openReleasePage(release)
                }
            } catch {
                Dialogs.updateError(l10n, detail: error.localizedDescription)
            }
        }
    }

    private static func openReleasePage(_ release: Release) {
        if let url = URL(string: release.htmlUrl) {
            NSWorkspace.shared.open(url)
        }
    }

    /// The release's zip asset paired with its Ed25519 signature asset, or
    /// nil when the release cannot be auto-installed. The archive name is
    /// the contract scripts/release.sh produces.
    private static func signedArchive(in release: Release, version: String) -> (archive: URL, signature: URL)? {
        let archiveName = "FlowerPassword-\(version).zip"
        guard
            let zip = release.assets.first(where: { $0.name == archiveName }),
            let signature = release.assets.first(where: { $0.name == zip.name + ".sig" }),
            let zipURL = URL(string: zip.browserDownloadUrl), zipURL.scheme == "https",
            let signatureURL = URL(string: signature.browserDownloadUrl),
            signatureURL.scheme == "https"
        else { return nil }
        return (zipURL, signatureURL)
    }

    private static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private struct Release: Decodable {
        let tagName: String
        let htmlUrl: String
        let assets: [Asset]

        struct Asset: Decodable {
            let name: String
            let browserDownloadUrl: String
        }
    }

    private struct HTTPStatusError: LocalizedError {
        let statusCode: Int
        var errorDescription: String? { "GitHub API returned \(statusCode)" }
    }

    private static func fetchLatestRelease() async throws -> Release {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw HTTPStatusError(statusCode: http.statusCode)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Release.self, from: data)
    }
}
