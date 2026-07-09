#!/usr/bin/env swift
// Ed25519 signing for release archives, used by .github/workflows/release.yml
// and verified in-app by FlowerPassword/Shell/SelfUpdater.swift.
//
//   generate <private-key-path>
//       Create a new keypair: write the base64 private key to the given
//       path (mode 0600, never printed) and print the base64 public key.
//       Store the private key as the ED25519_PRIVATE_KEY repo secret and
//       embed the public key in SelfUpdater.swift.
//   sign <file>
//       Read the base64 private key from the ED25519_PRIVATE_KEY
//       environment variable and write <file>.sig (base64 signature).
//   verify <base64-public-key> <file> <signature-file>
//       Exit 0 when the signature matches the file.

import CryptoKit
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func run() throws {
    let arguments = CommandLine.arguments
    guard arguments.count >= 2 else {
        fail("usage: sign-update.swift generate <private-key-path> | sign <file> | verify <public-key> <file> <sig>")
    }

    switch arguments[1] {
    case "generate":
        guard arguments.count == 3 else { fail("usage: generate <private-key-path>") }
        let path = arguments[2]
        guard !FileManager.default.fileExists(atPath: path) else {
            fail("refusing to overwrite existing key at \(path)")
        }
        let key = Curve25519.Signing.PrivateKey()
        let encoded = Data(key.rawRepresentation.base64EncodedString().utf8)
        guard
            FileManager.default.createFile(
                atPath: path, contents: encoded, attributes: [.posixPermissions: 0o600])
        else { fail("could not write private key to \(path)") }
        print(key.publicKey.rawRepresentation.base64EncodedString())

    case "sign":
        guard arguments.count == 3 else { fail("usage: sign <file>") }
        guard
            let encoded = ProcessInfo.processInfo.environment["ED25519_PRIVATE_KEY"],
            let keyData = Data(
                base64Encoded: encoded.trimmingCharacters(in: .whitespacesAndNewlines))
        else { fail("ED25519_PRIVATE_KEY must hold the base64 private key") }
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
        let payload = try Data(contentsOf: URL(fileURLWithPath: arguments[2]))
        let signaturePath = arguments[2] + ".sig"
        try (key.signature(for: payload).base64EncodedString() + "\n")
            .write(toFile: signaturePath, atomically: true, encoding: .utf8)
        print(signaturePath)

    case "verify":
        guard arguments.count == 5 else { fail("usage: verify <public-key> <file> <sig>") }
        guard let keyData = Data(base64Encoded: arguments[2]) else {
            fail("invalid base64 public key")
        }
        let key = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
        let payload = try Data(contentsOf: URL(fileURLWithPath: arguments[3]))
        let signatureText = try String(contentsOfFile: arguments[4], encoding: .utf8)
        guard
            let signature = Data(
                base64Encoded: signatureText.trimmingCharacters(in: .whitespacesAndNewlines)),
            key.isValidSignature(signature, for: payload)
        else { fail("signature does NOT match \(arguments[3])") }
        print("signature OK")

    default:
        fail("unknown command: \(arguments[1])")
    }
}

do {
    try run()
} catch {
    fail("error: \(error.localizedDescription)")
}
