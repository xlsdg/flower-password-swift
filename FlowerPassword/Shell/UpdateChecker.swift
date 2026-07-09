import AppKit

/// Manual update check against the GitHub releases API: compare the latest
/// tag against the bundle version, offer to open the release page, and
/// report errors verbatim.
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
            let l10n = L10n.strings(for: state.effectiveLanguage)
            do {
                let release = try await Self.fetchLatestRelease()
                let current = Self.currentVersion
                let latest =
                    release.tagName.hasPrefix("v")
                    ? String(release.tagName.dropFirst()) : release.tagName
                if latest.compare(current, options: .numeric) == .orderedDescending {
                    if Dialogs.updateAvailable(l10n, current: current, latest: latest),
                        let url = URL(string: release.htmlURL)
                    {
                        NSWorkspace.shared.open(url)
                    }
                } else {
                    Dialogs.noUpdate(l10n, version: current)
                }
            } catch {
                Dialogs.updateError(l10n, detail: error.localizedDescription)
            }
        }
    }

    private static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private struct Release: Decodable {
        let tagName: String
        let htmlURL: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
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
        return try JSONDecoder().decode(Release.self, from: data)
    }
}
