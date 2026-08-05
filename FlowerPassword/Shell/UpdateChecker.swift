import AppKit

import FlowerPasswordCore

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
                let latest = release.normalizedVersion
                let decision = ReleaseDecision.decide(currentVersion: current, release: release)

                switch decision {
                case .upToDate:
                    Dialogs.noUpdate(l10n, version: current)

                case .installable(let archiveURL, let signatureURL):
                    guard Dialogs.updateAvailable(l10n, current: current, latest: latest) else {
                        return
                    }
                    do {
                        // On success install() relaunches and never returns.
                        try await SelfUpdater.install(
                            zipURL: archiveURL,
                            signatureURL: signatureURL,
                            expectedVersion: latest
                        )
                    } catch {
                        if Dialogs.updateInstallFailed(l10n, detail: error.localizedDescription),
                            let url = URL(string: release.htmlUrl)
                        {
                            NSWorkspace.shared.open(url)
                        }
                    }

                case .manualOnly(let pageURL):
                    if Dialogs.updateAvailableManual(l10n, current: current, latest: latest) {
                        NSWorkspace.shared.open(pageURL)
                    }
                }
            } catch {
                Dialogs.updateError(l10n, detail: error.localizedDescription)
            }
        }
    }

    private static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
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
