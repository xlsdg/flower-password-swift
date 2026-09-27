import AppKit

import FlowerPasswordCore

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
                if await Self.shouldOpenReleasePage(release) {
                    NSWorkspace.shared.open(release.pageURL)
                }
            } catch {
                Dialogs.updateError(detail: error.localizedDescription)
            }
        }
    }

    private static func shouldOpenReleasePage(_ release: Release) async -> Bool {
        let current = currentVersion
        let latest = release.normalizedVersion
        switch ReleaseDecision.decide(currentVersion: current, release: release) {
        case .upToDate:
            Dialogs.noUpdate(version: current)
            return false
        case .installable(let archiveURL, let signatureURL):
            guard Dialogs.updateAvailableInstall(current: current, latest: latest) else { return false }
            do {
                try await SelfUpdater.install(
                    zipURL: archiveURL, signatureURL: signatureURL, expectedVersion: latest)
                return false
            } catch {
                return Dialogs.updateInstallFailed(detail: error.localizedDescription)
            }
        case .manualOnly:
            return Dialogs.updateAvailableManual(current: current, latest: latest)
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
