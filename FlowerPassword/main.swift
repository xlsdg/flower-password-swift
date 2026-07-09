import AppKit

// The process entry point always runs on the main thread; assumeIsolated
// makes that visible to the compiler so the @MainActor delegate can be
// constructed here. `delegate` stays alive for the whole run() loop because
// NSApplication.delegate is not retained.
MainActor.assumeIsolated {
    let delegate = AppDelegate()
    let app = NSApplication.shared
    app.delegate = delegate
    // Menu-bar-only app: no Dock icon, no app-switcher entry (paired with
    // LSUIElement in Info.plist).
    app.setActivationPolicy(.accessory)
    app.run()
}
