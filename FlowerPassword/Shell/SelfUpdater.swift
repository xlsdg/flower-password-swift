import AppKit
import CryptoKit

/// Replaces the running app bundle with a downloaded release archive:
/// verify the Ed25519 signature, extract, swap in place, and relaunch.
/// A detached helper retains the old bundle until the new app acknowledges startup.
enum SelfUpdater {
    /// Pairs with the ED25519_PRIVATE_KEY repo secret that CI uses to sign
    /// release archives (scripts/sign-update.swift); release.yml refuses to
    /// publish when the two no longer match.
    private static var publicKeyBase64: String {
        guard let url = Bundle.main.url(forResource: "update-public-key", withExtension: "txt"),
              let key = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Carries no prose: the user-facing sentences live in `L10n`, rendered
    /// by `UpdateChecker`, so all three languages stay in one place.
    /// `wrongBundle`'s reason is developer diagnostics and stays English.
    enum UpdateError: Error {
        case translocated
        case notWritable(String)
        case volumeIgnoresOwnership(String)
        case invalidResponse
        case httpStatus(Int)
        case downloadTooLarge(bytes: Int, limit: Int)
        case invalidSignature
        case extractionFailed(Int32)
        case appMissingFromArchive
        case wrongBundle(String)
    }

    /// Downloads, verifies, and installs the update, then relaunches.
    /// On success this never returns: the process terminates and the new
    /// version is opened by a detached helper.
    ///
    /// Contains blocking process waits, so it must stay off the main actor.
    /// As a nonisolated async function it runs on the global executor today;
    /// revisit if the project ever adopts main-actor-by-default isolation.
    static func install(
        zipURL: URL,
        signatureURL: URL,
        expectedVersion: String
    ) async throws {
        let bundleURL = Bundle.main.bundleURL
        try preflight(bundleURL)

        async let archive = fetch(zipURL, limit: maxArchiveBytes)
        async let signature = fetch(signatureURL, limit: maxSignatureBytes)
        let (archiveData, signatureData) = try await (archive, signature)
        try verify(archive: archiveData, signature: signatureData)

        // itemReplacementDirectory keeps staging on the same volume as the
        // installed app, so the swap below is a pure rename.
        let staging = try FileManager.default.url(
            for: .itemReplacementDirectory, in: .userDomainMask,
            appropriateFor: bundleURL, create: true)
        var handedOff = false
        defer { if !handedOff { try? FileManager.default.removeItem(at: staging) } }

        let newApp = try extract(archiveData, in: staging)
        try validate(newApp, expectedVersion: expectedVersion)
        try await relaunch(bundleURL, newApp: newApp, staging: staging)
        handedOff = true
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
        try response.validateSuccessStatus()
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

        try FileManager.default.createDirectory(at: unpacked, withIntermediateDirectories: false)
        // Enforce containment during extraction, not after a traversal could write.
        // ponytail: sandbox-exec is deprecated; fail closed if unavailable, replace
        // with a sandboxed extraction helper when macOS removes it.
        let profile = "(version 1)(allow default)(deny file-write*)(allow file-write* (subpath (param \"DEST\")))"
        // realpath(3) canonicalizes /var -> /private/var;
        // resolvingSymlinksInPath does not, and both the sandbox subpath rule
        // and the prefix check below compare canonical paths.
        func canonical(_ url: URL) -> String {
            url.withUnsafeFileSystemRepresentation { ptr in
                guard let ptr, let real = realpath(ptr, nil) else { return url.path }
                defer { free(real) }
                return String(cString: real)
            }
        }
        let root = canonical(unpacked)
        let status = run("/usr/bin/sandbox-exec", [
            "-D", "DEST=\(root)", "-p", profile,
            "/usr/bin/ditto", "-xk", zipFile.path, unpacked.path,
        ])
        guard status == 0 else {
            throw UpdateError.extractionFailed(status)
        }

        guard let entries = FileManager.default.enumerator(at: unpacked,
            includingPropertiesForKeys: [.isSymbolicLinkKey]) else {
            throw UpdateError.appMissingFromArchive
        }
        for case let entry as URL in entries {
            guard canonical(entry).hasPrefix(root + "/") else {
                throw UpdateError.wrongBundle("archive contains an escaping symbolic link")
            }
        }
        let contents = try FileManager.default.contentsOfDirectory(
            at: unpacked, includingPropertiesForKeys: nil)
        let apps = contents.filter { $0.pathExtension == "app" }
        guard apps.count == 1, let app = apps.first else {
            throw UpdateError.appMissingFromArchive
        }

        // URLSession and ditto do not quarantine, but strip defensively so
        // the relaunch can never hit a Gatekeeper prompt.
        run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", app.path], quiet: true)

        return app
    }

    /// Runs a tool to completion and returns its exit status, or -1 when it
    /// could not be launched at all.
    @discardableResult
    private static func run(_ tool: String, _ arguments: [String], quiet: Bool = false) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        if quiet {
            process.standardError = FileHandle.nullDevice
        }
        guard (try? process.run()) != nil else { return -1 }
        process.waitUntilExit()
        return process.terminationStatus
    }

    private static var currentArchitecture: Int {
        #if arch(arm64)
        return NSBundleExecutableArchitectureARM64
        #else
        return NSBundleExecutableArchitectureX86_64
        #endif
    }

    private static func validate(_ app: URL, expectedVersion: String) throws {
        guard let bundle = Bundle(url: app) else {
            throw UpdateError.wrongBundle("unreadable bundle")
        }
        guard bundle.bundleIdentifier == Bundle.main.bundleIdentifier else {
            throw UpdateError.wrongBundle(
                "unexpected bundle identifier \(bundle.bundleIdentifier ?? "nil")")
        }
        guard let executable = bundle.executableURL,
              FileManager.default.isExecutableFile(atPath: executable.path),
              let architectures = bundle.executableArchitectures,
              architectures.contains(NSNumber(value: currentArchitecture)),
              run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path]) == 0 else {
            throw UpdateError.wrongBundle("missing executable, unsupported architecture, or invalid code signature")
        }
        let version = bundle.shortVersion
        guard version == expectedVersion else {
            throw UpdateError.wrongBundle(
                "version \(version ?? "nil") does not match release \(expectedVersion)")
        }
    }

    @MainActor
    private static func relaunch(_ bundleURL: URL, newApp: URL, staging: URL) throws {
        guard let script = Bundle.main.url(forResource: "install-update", withExtension: "sh"),
              let executable = Bundle(url: newApp)?.executableURL?.lastPathComponent else {
            throw UpdateError.wrongBundle("missing update helper or executable")
        }
        let helper = staging.appendingPathComponent("install-update.sh")
        try FileManager.default.copyItem(at: script, to: helper)
        let pid = ProcessInfo.processInfo.processIdentifier
        let waiter = Process()
        waiter.executableURL = URL(fileURLWithPath: "/bin/sh")
        waiter.arguments = [
            helper.path, String(pid), bundleURL.path, staging.path, newApp.path, executable,
        ]
        try waiter.run()
        // Return to install() first so it transfers ownership of staging.
        DispatchQueue.main.async { NSApp.terminate(nil) }
    }
}

extension URLResponse {
    func validateSuccessStatus() throws {
        guard let response = self as? HTTPURLResponse else {
            throw SelfUpdater.UpdateError.invalidResponse
        }
        guard (200...299).contains(response.statusCode) else {
            throw SelfUpdater.UpdateError.httpStatus(response.statusCode)
        }
    }
}

extension Bundle {
    /// The bundle's marketing version — the single place the
    /// CFBundleShortVersionString key is spelled out.
    var shortVersion: String? {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
}
