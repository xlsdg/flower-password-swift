import AppKit
import ApplicationServices

/// Reads the active tab's URL from a known browser. Safari and Chromium
/// browsers answer Apple Events (the system asks the user once per browser);
/// Gecko browsers have no scripting dictionary, so their accessibility tree
/// is read instead, only when Accessibility is already granted.
@MainActor
enum BrowserURLReader {
    private enum Source {
        case appleEvent(String)
        case accessibility
    }

    private static let safari = "get URL of front document"
    private static let chromium = "get URL of active tab of front window"

    private static let sources: [String: Source] = [
        "com.apple.Safari": .appleEvent(safari),
        "com.apple.SafariTechnologyPreview": .appleEvent(safari),
        "com.google.Chrome": .appleEvent(chromium),
        "com.google.Chrome.beta": .appleEvent(chromium),
        "com.google.Chrome.dev": .appleEvent(chromium),
        "com.google.Chrome.canary": .appleEvent(chromium),
        "org.chromium.Chromium": .appleEvent(chromium),
        "com.microsoft.edgemac": .appleEvent(chromium),
        "com.brave.Browser": .appleEvent(chromium),
        "com.vivaldi.Vivaldi": .appleEvent(chromium),
        "com.operasoftware.Opera": .appleEvent(chromium),
        "company.thebrowser.Browser": .appleEvent(chromium),
        "org.mozilla.firefox": .accessibility,
        "org.mozilla.firefoxdeveloperedition": .accessibility,
        "org.mozilla.nightly": .accessibility,
        "app.zen-browser.zen": .accessibility,
        "io.gitlab.librewolf-community": .accessibility,
    ]

    private static var scripts: [String: NSAppleScript] = [:]

    /// Runs synchronously before the panel activates: a first-use Automation
    /// prompt would otherwise take key status and dismiss the panel.
    static func activeTabURL(of app: NSRunningApplication?) -> String? {
        guard let app, let bundleID = app.bundleIdentifier, let source = sources[bundleID] else {
            return nil
        }
        switch source {
        case .appleEvent(let command):
            return runAppleScript(command, bundleID: bundleID)
        case .accessibility:
            return webAreaURL(pid: app.processIdentifier)
        }
    }

    private static func runAppleScript(_ command: String, bundleID: String) -> String? {
        // Blocks until the user answers a first-use prompt; the script's own
        // timeout would otherwise expire and leave the prompt over the panel.
        guard let target = NSAppleEventDescriptor(bundleIdentifier: bundleID).aeDesc,
            AEDeterminePermissionToAutomateTarget(target, typeWildCard, typeWildCard, true) == noErr
        else { return nil }
        let script: NSAppleScript
        if let cached = scripts[bundleID] {
            script = cached
        } else {
            let source = """
                with timeout of 1 second
                    tell application id "\(bundleID)" to \(command)
                end timeout
                """
            guard let compiled = NSAppleScript(source: source) else { return nil }
            scripts[bundleID] = compiled
            script = compiled
        }
        var error: NSDictionary?
        return script.executeAndReturnError(&error).stringValue
    }

    /// Breadth-first search of the focused window for the first web area,
    /// whose AXURL is the active tab's full URL (the address bar drops the
    /// scheme and shows typed text while editing). Gecko builds the web
    /// content tree only once AXEnhancedUserInterface is set, and asynchronously,
    /// so the first read after a browser launch polls briefly.
    private static func webAreaURL(pid: pid_t) -> String? {
        guard AutoTypeService.isTrusted(prompt: false) else { return nil }
        // Only the system-wide element's timeout covers every element reached below.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.5)
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        let deadline = Date().addingTimeInterval(0.3)
        repeat {
            if let url = firstWebAreaURL(app) { return url }
            usleep(20_000)
        } while Date() < deadline
        return nil
    }

    private static func firstWebAreaURL(_ app: AXUIElement) -> String? {
        guard let window = attribute(app, kAXFocusedWindowAttribute) else { return nil }
        // ponytail: node cap bounds a pathological tree; the web area sits ~5 levels deep.
        var queue = [window as! AXUIElement]
        var index = 0
        while index < queue.count, index < 2000 {
            let element = queue[index]
            index += 1
            if attribute(element, kAXRoleAttribute) as? String == "AXWebArea" {
                return (attribute(element, kAXURLAttribute) as? URL)?.absoluteString
            }
            queue += attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
        }
        return nil
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }
}
