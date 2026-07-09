# FlowerPassword

A native Swift menu bar app for macOS that generates site-specific passwords with the Flower Password method.

Flower Password is a "nothing stored" approach to password management: remember one **memory password**, pick a short **distinction code** for each site (like `taobao` or `github`), and the app derives a strong site-specific password on the fly with a one-way algorithm. Nothing is saved, nothing is synced, and nothing can be reversed — you can always re-derive any password.

## Features

- Lives in the menu bar; open the panel with a click or the global shortcut (⌘⌥S by default)
- Type the memory password and distinction code, press Return — the password is copied and the panel hides
- Password length from 6 to 32 characters, with optional custom prefix/suffix
- Clipboard clears itself 10 seconds after a copy (and leaves anything you copied in the meantime alone)
- If the clipboard holds a URL, the registrable domain is prefilled as the distinction code (`www.google.co.uk` → `google`)
- Light / dark / system themes; English, Simplified Chinese, and Traditional Chinese UI
- Optional launch at login; manual update check

## Install

Download the latest `FlowerPassword-x.y.z.zip` from [Releases](https://github.com/xlsdg/flower-password-swift/releases), unzip it, and drag `FlowerPassword.app` into your Applications folder.

The app is not notarized yet, so macOS will warn that it cannot verify the developer on first launch. Allow it once:

### macOS 15 and later

1. Double-click the app and click "Done" in the dialog
2. Open System Settings → Privacy & Security and scroll to the Security section
3. Click "Open Anyway" and confirm

### macOS 14

Right-click (or Control-click) `FlowerPassword.app` and choose "Open", then click "Open" in the dialog.

Alternatively, remove the quarantine attribute in Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/FlowerPassword.app
```

## Usage

1. Click the menu bar icon or press ⌘⌥S (the app lives in the menu bar only — no Dock icon)
2. Enter your memory password and a distinction code
3. Press Return or click the generate button — the password is on your clipboard, ready to paste

Right-click the menu bar icon to change the theme, language, launch at login, the global shortcut, or to check for updates.

## How Flower Password works

One memory password + one distinction code per site = one strong password per site.

For example, memory password `123456` with distinction code `taobao` yields `KfdDf77F7D64e5c0`.

- The same input always produces the same output, so nothing ever needs to be stored
- The derivation is a one-way HMAC-MD5 construction; the memory password cannot be recovered from a generated password
- The output matches [flowerpassword.com](https://flowerpassword.com/) and the other Flower Password clients, verified by a 42-case golden-vector test suite

## Privacy

- The memory password lives in memory only and is **never written to disk**; the app stores and syncs no passwords
- The only network request is the manual "Check for Updates" call to the GitHub Releases API — no telemetry, no analytics, no automatic connections

## Performance

Native Swift with SwiftUI/AppKit and zero third-party dependencies. Measured on Apple Silicon:

- Cold start in about 34 ms
- About 27 MB resident memory
- About 1 MB on disk

## Build from source

Requires macOS 14+ and Xcode 16+:

```bash
git clone https://github.com/xlsdg/flower-password-swift.git
cd flower-password-swift

# Run the algorithm test suite
swift test --package-path FlowerPasswordCore

# Build the app
xcodebuild -project FlowerPassword.xcodeproj -scheme FlowerPassword -configuration Release build
```

Only system frameworks are used (SwiftUI, AppKit, CryptoKit, Carbon, ServiceManagement).

## License

[Apache License 2.0](LICENSE)
