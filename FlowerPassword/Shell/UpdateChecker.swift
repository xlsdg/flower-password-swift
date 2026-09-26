import AppKit

import FlowerPasswordCore

/// Manual update check against the GitHub releases API: compare the latest
/// tag against the bundle version and, when the release carries a signed
/// archive, download, verify, install, and relaunch in place. Releases
/// without a signature fall back to opening the release page, as does any
/// install failure.
@MainActor
final class UpdateChecker {
    private var isChecking = false

    private static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/xlsdg/flower-password-swift/releases/latest")!

    func check() {
        guard !isChecking else { return }
        isChecking = true
        Task {
            defer { isChecking = false }
            do {
                let release = try await Self.fetchLatestRelease()
                let current = Self.currentVersion
                let latest = release.normalizedVersion
                let decision = ReleaseDecision.decide(currentVersion: current, release: release)

                switch decision {
                case .upToDate:
                    Dialogs.noUpdate(version: current)

                case .installable(let archiveURL, let signatureURL):
                    guard Dialogs.updateAvailableInstall(current: current, latest: latest) else {
                        return
                    }
                    do {
                        try await SelfUpdater.install(
                            zipURL: archiveURL,
                            signatureURL: signatureURL,
                            expectedVersion: latest
                        )
                    } catch {
                        if Dialogs.updateInstallFailed(detail: error.localizedDescription) {
                            NSWorkspace.shared.open(release.pageURL)
                        }
                    }

                case .manualOnly:
                    if Dialogs.updateAvailableManual(current: current, latest: latest) {
                        NSWorkspace.shared.open(release.pageURL)
                    }
                }
            } catch {
                Dialogs.updateError(detail: error.localizedDescription)
            }
        }
    }

    private static var currentVersion: String {
        Bundle.main.shortVersion ?? "0.0.0"
    }

    private static func fetchLatestRelease() async throws -> Release {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        try response.validateSuccessStatus()
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Release.self, from: data)
    }
}
