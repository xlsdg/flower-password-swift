import AppKit
import SwiftUI

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
    private var updateWindow: NSWindow?
    private var progressWindow: NSWindow?

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
                    let shouldInstall = await showUpdateWindow(
                        current: current,
                        latest: latest,
                        releaseNotes: release.body
                    )
                    guard shouldInstall else { return }

                    let progressState = DownloadProgress()
                    await showProgressWindow(with: progressState)
                    do {
                        try await SelfUpdater.install(
                            zipURL: archiveURL,
                            signatureURL: signatureURL,
                            expectedVersion: latest,
                            progressHandler: { progress in
                                await MainActor.run {
                                    progressState.value = progress
                                }
                            }
                        )
                    } catch {
                        await closeProgressWindow()
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

    private func showUpdateWindow(current: String, latest: String, releaseNotes: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let l10n = state.l10n
            var shouldInstall = false

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = l10n.updateWindowTitle
            window.center()
            window.isReleasedWhenClosed = false

            let hostingView = NSHostingView(
                rootView: UpdateWindow(
                    currentVersion: current,
                    newVersion: latest,
                    releaseNotes: releaseNotes,
                    l10n: l10n,
                    onInstall: {
                        shouldInstall = true
                        window.close()
                    },
                    onSkip: {
                        shouldInstall = false
                        window.close()
                    }
                )
            )
            window.contentView = hostingView
            self.updateWindow = window
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.updateWindow = nil
                continuation.resume(returning: shouldInstall)
            }
        }
    }

    private func showProgressWindow(with progress: DownloadProgress) async {
        let l10n = state.l10n
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 120),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = l10n.updateDownloading
        window.center()
        window.isReleasedWhenClosed = false

        let hostingView = NSHostingView(
            rootView: UpdateProgressWindow(progress: progress, l10n: l10n)
        )
        window.contentView = hostingView
        self.progressWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeProgressWindow() async {
        await MainActor.run {
            progressWindow?.close()
            progressWindow = nil
        }
    }
}
