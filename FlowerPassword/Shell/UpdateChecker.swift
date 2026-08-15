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

    private static func fetchLatestRelease() async throws -> Release {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        try (response as? HTTPURLResponse)?.validateSuccessStatus()
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Release.self, from: data)
    }

    private func showUpdateWindow(current: String, latest: String, releaseNotes: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let l10n = state.l10n
            var shouldInstall = false

            var window: NSWindow!
            window = makeWindow(
                size: NSSize(width: 520, height: 440),
                title: l10n.updateWindowTitle,
                styleMask: [.titled, .closable],
                content: UpdateWindow(
                    currentVersion: current,
                    newVersion: latest,
                    releaseNotes: releaseNotes,
                    l10n: l10n,
                    onInstall: {
                        shouldInstall = true
                        window.close()
                    },
                    onSkip: {
                        window.close()
                    }
                )
            )
            self.updateWindow = window
            present(window)

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

    private func makeWindow<V: View>(
        size: NSSize,
        title: String,
        styleMask: NSWindow.StyleMask,
        content: V
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content)
        return window
    }

    private func present(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showProgressWindow(with progress: DownloadProgress) async {
        let window = makeWindow(
            size: NSSize(width: 400, height: 120),
            title: state.l10n.updateDownloading,
            styleMask: [.titled],
            content: UpdateProgressWindow(progress: progress, l10n: state.l10n)
        )
        self.progressWindow = window
        present(window)
    }

    private func closeProgressWindow() async {
        progressWindow?.close()
        progressWindow = nil
    }
}
