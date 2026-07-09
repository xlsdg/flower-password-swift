import AppKit
import CryptoKit

/// Replaces the running app bundle with a downloaded release archive:
/// verify the Ed25519 signature, extract, swap in place, and relaunch.
/// Nothing is modified until the swap step, a single replaceItemAt call
/// that restores the original bundle if the replacement fails.
enum SelfUpdater {
    /// Pairs with the ED25519_PRIVATE_KEY repo secret that CI uses to sign
    /// release archives (scripts/sign-update.swift); release.yml refuses to
    /// publish when the two no longer match.
    private static let publicKeyBase64 = "qf1aoyEllNVxl+neetyWDbL2tx3m1IA89qz/F0iD+7k="

    enum UpdateError: LocalizedError {
        case translocated
        case notWritable(String)
        case volumeIgnoresOwnership(String)
        case httpStatus(Int)
        case downloadTooLarge(bytes: Int, limit: Int)
        case invalidSignature
        case extractionFailed(Int32)
        case appMissingFromArchive
        case wrongBundle(String)

        var errorDescription: String? {
            switch self {
            case .translocated:
                "The app is running from a translocated path. Move FlowerPassword.app to /Applications and try again."
            case .notWritable(let directory):
                "No permission to replace the app in \(directory)."
            case .volumeIgnoresOwnership(let directory):
                "The volume holding \(directory) ignores file ownership, so in-place updates are unsafe there."
            case .httpStatus(let status):
                "Download failed with HTTP \(status)."
            case .downloadTooLarge(let bytes, let limit):
                "The download is \(bytes) bytes, above the \(limit)-byte limit."
            case .invalidSignature:
                "The update failed signature verification; the download may be corrupted or tampered with."
            case .extractionFailed(let status):
                "Could not extract the update archive (ditto exited with \(status))."
            case .appMissingFromArchive:
                "The update archive does not contain an app bundle."
            case .wrongBundle(let reason):
                "The downloaded app failed validation: \(reason)."
            }
        }
    }

    /// Downloads, verifies, and installs the update, then relaunches.
    /// On success this never returns: the process terminates and the new
    /// version is opened by a detached helper.
    ///
    /// Contains blocking process waits, so it must stay off the main actor.
    /// As a nonisolated async function it runs on the global executor today;
    /// revisit if the project ever adopts main-actor-by-default isolation.
    static func install(zipURL: URL, signatureURL: URL, expectedVersion: String) async throws {
        let bundleURL = Bundle.main.bundleURL
        try preflight(bundleURL)

        let archive = try await fetch(zipURL, limit: maxArchiveBytes)
        let signature = try await fetch(signatureURL, limit: maxSignatureBytes)
        try verify(archive: archive, signature: signature)

        // itemReplacementDirectory keeps staging on the same volume as the
        // installed app, so the swap below is a pure rename.
        let staging = try FileManager.default.url(
            for: .itemReplacementDirectory, in: .userDomainMask,
            appropriateFor: bundleURL, create: true)
        defer { try? FileManager.default.removeItem(at: staging) }

        let newApp = try extract(archive, in: staging)
        try validate(newApp, expectedVersion: expectedVersion)
        // Replacing the running bundle is safe: the kernel keeps the mapped
        // binary alive until the process exits.
        _ = try FileManager.default.replaceItemAt(bundleURL, withItemAt: newApp)
        await relaunch(bundleURL)
    }

    private static func preflight(_ bundleURL: URL) throws {
        guard !bundleURL.path.contains("/AppTranslocation/") else {
            throw UpdateError.translocated
        }
        let parent = bundleURL.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: parent.path) else {
            throw UpdateError.notWritable(parent.path)
        }
        // On an ignore-ownership volume the staging directory created by
        // install() is writable by every local user, who could then swap the
        // extracted app between validation and the final rename.
        var fs = statfs()
        if statfs(parent.path, &fs) == 0, fs.f_flags & UInt32(MNT_IGNORE_OWNERSHIP) != 0 {
            throw UpdateError.volumeIgnoresOwnership(parent.path)
        }
    }

    /// Far above any real release (the app is about 1 MB) while still
    /// bounding memory if a compromised release attaches a huge asset.
    private static let maxArchiveBytes = 50 << 20
    private static let maxSignatureBytes = 4096

    /// Downloads to a temporary file and returns its bytes, refusing files
    /// larger than `limit`: release assets are attacker-sized until the
    /// signature check passes, and the caller buffers the result in memory.
    private static func fetch(_ url: URL, limit: Int) async throws -> Data {
        let (file, response) = try await URLSession.shared.download(from: url)
        defer { try? FileManager.default.removeItem(at: file) }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw UpdateError.httpStatus(http.statusCode)
        }
        let bytes = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard bytes <= limit else {
            throw UpdateError.downloadTooLarge(bytes: bytes, limit: limit)
        }
        return try Data(contentsOf: file)
    }

    private static func verify(archive: Data, signature: Data) throws {
        guard
            let keyData = Data(base64Encoded: publicKeyBase64),
            let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData),
            let signatureText = String(data: signature, encoding: .utf8),
            let signatureData = Data(
                base64Encoded: signatureText.trimmingCharacters(in: .whitespacesAndNewlines)),
            key.isValidSignature(signatureData, for: archive)
        else { throw UpdateError.invalidSignature }
    }

    private static func extract(_ archive: Data, in staging: URL) throws -> URL {
        let zipFile = staging.appendingPathComponent("update.zip")
        try archive.write(to: zipFile)
        let unpacked = staging.appendingPathComponent("unpacked", isDirectory: true)

        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-xk", zipFile.path, unpacked.path]
        try ditto.run()
        ditto.waitUntilExit()
        guard ditto.terminationStatus == 0 else {
            throw UpdateError.extractionFailed(ditto.terminationStatus)
        }

        let contents = try FileManager.default.contentsOfDirectory(
            at: unpacked, includingPropertiesForKeys: nil)
        guard let app = contents.first(where: { $0.pathExtension == "app" }) else {
            throw UpdateError.appMissingFromArchive
        }

        // URLSession and ditto do not quarantine, but strip defensively so
        // the relaunch can never hit a Gatekeeper prompt.
        let xattr = Process()
        xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattr.arguments = ["-dr", "com.apple.quarantine", app.path]
        xattr.standardError = FileHandle.nullDevice
        if (try? xattr.run()) != nil {
            xattr.waitUntilExit()
        }

        return app
    }

    private static func validate(_ app: URL, expectedVersion: String) throws {
        guard let bundle = Bundle(url: app) else {
            throw UpdateError.wrongBundle("unreadable bundle")
        }
        guard bundle.bundleIdentifier == Bundle.main.bundleIdentifier else {
            throw UpdateError.wrongBundle(
                "unexpected bundle identifier \(bundle.bundleIdentifier ?? "nil")")
        }
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        guard version == expectedVersion else {
            throw UpdateError.wrongBundle(
                "version \(version ?? "nil") does not match release \(expectedVersion)")
        }
    }

    @MainActor
    private static func relaunch(_ bundleURL: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let waiter = Process()
        waiter.executableURL = URL(fileURLWithPath: "/bin/sh")
        waiter.arguments = [
            "-c",
            "while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.1; done; /usr/bin/open \"$1\"",
            "relaunch",
            bundleURL.path,
        ]
        try? waiter.run()
        NSApp.terminate(nil)
    }
}
