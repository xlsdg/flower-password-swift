import AppKit
import XCTest

/// End-to-end checks of the menu-bar app. The app runs with `--ui-testing`
/// (wiped private defaults suite, no global hotkey) and English UI strings.
/// Global shortcut, auto-type, launch at login, and updates stay manual:
/// they need system permissions, change system state, or hit the network.
@MainActor
final class FlowerPasswordUITests: XCTestCase {
    /// Expected values come from FlowerPasswordCore, whose algorithm is
    /// pinned by the golden-vector tests.
    private enum Expected {
        static let testGithub16 = "KD980e474445d188"
        static let testGithub8 = "KD980e47"
        static let testPreGithubSuf16 = "K6657cF54E72D444"
    }

    private var app: XCUIApplication!

    private var statusItem: XCUIElement { app.statusItems["statusItem"] }
    private var passwordField: XCUIElement { app.secureTextFields["password"] }
    private var keyField: XCUIElement { app.textFields["key"] }
    private var prefixField: XCUIElement { app.textFields["prefix"] }
    private var suffixField: XCUIElement { app.textFields["suffix"] }
    private var generateButton: XCUIElement { app.buttons["generate"] }
    private var lengthButton: XCUIElement { app.buttons["length"] }
    private var closeButton: XCUIElement { app.buttons["close"] }

    // MARK: - Panel

    func testStatusItemTogglesPanel() {
        launch()
        openPanel()
        statusItem.click()
        XCTAssertTrue(passwordField.waitForNonExistence(timeout: 3))
        openPanel()
    }

    func testShowMenuItemOpensPanel() {
        launch()
        pickMenu("Show")
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3))
    }

    func testEscClosesPanel() {
        launch()
        openPanel()
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(passwordField.waitForNonExistence(timeout: 3))
    }

    func testCloseButtonClosesPanel() {
        launch()
        openPanel()
        closeButton.click()
        XCTAssertTrue(passwordField.waitForNonExistence(timeout: 3))
    }

    func testPanelHidesWhenItLosesFocus() {
        launch()
        openPanel()
        XCUIApplication(bundleIdentifier: "com.apple.finder").activate()
        XCTAssertTrue(passwordField.waitForNonExistence(timeout: 3))
    }

    func testCaretStartsInKeyFieldOncePasswordIsFilled() {
        launch()
        openPanel()
        app.typeText("test")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(passwordField.waitForNonExistence(timeout: 3))
        openPanel()
        app.typeText("github")
        XCTAssertEqual(keyField.value as? String, "github")
    }

    // MARK: - Generating

    func testGenerateCopiesPasswordAndClearsClipboardAfterTenSeconds() async {
        launch()
        openPanel()
        fill(password: "test", key: "github")
        generateButton.click()
        XCTAssertTrue(passwordField.waitForNonExistence(timeout: 3))
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), Expected.testGithub16)

        let cleared = await waitUntil(timeout: 14) { NSPasteboard.general.string(forType: .string) == nil }
        XCTAssertTrue(cleared, "the copied password must be cleared after 10 seconds")
    }

    func testEnterInKeyFieldGenerates() {
        launch()
        openPanel()
        fill(password: "test", key: "github")
        keyField.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(passwordField.waitForNonExistence(timeout: 3))
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), Expected.testGithub16)
    }

    func testPrefixAndSuffixWrapTheKey() {
        launch()
        openPanel()
        fill(password: "test", key: "github")
        prefixField.click()
        prefixField.typeText("pre-")
        suffixField.click()
        suffixField.typeText("-suf")
        generateButton.click()
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), Expected.testPreGithubSuf16)
    }

    func testLengthMenuChangesPasswordLength() {
        launch()
        openPanel()
        fill(password: "test", key: "github")
        lengthButton.click()
        app.menuItems["08 chars"].click()
        XCTAssertEqual(lengthButton.value as? String, "08 chars")
        generateButton.click()
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), Expected.testGithub8)
    }

    func testGenerateButtonMasksCodeUntilHovered() {
        launch()
        openPanel()
        XCTAssertEqual(generateButton.title, "Generate Password (Click to Copy)")
        fill(password: "test", key: "github")
        keyField.click()
        XCTAssertEqual(generateButton.title, "KD••••••••••••88")
        generateButton.hover()
        XCTAssertEqual(generateButton.title, Expected.testGithub16)
    }

    func testClipboardURLPrefillsKey() {
        launch()
        setPasteboard("https://www.github.com/xlsdg/flower-password-swift")
        openPanel()
        XCTAssertEqual(keyField.value as? String, "github")
    }

    func testClipboardTextThatIsNotAURLLeavesKeyAlone() {
        launch()
        setPasteboard("github.com")
        openPanel()
        XCTAssertNotEqual(keyField.value as? String, "github")
    }

    // MARK: - Menu settings

    func testLanguageMenuSwitchesUIStrings() {
        launch()
        pickMenu("Language", "简体中文")
        openPanel()
        XCTAssertEqual(passwordField.placeholderValue, "记忆密码")
    }

    func testThemeMenuSwitchesAppearance() {
        launch()
        pickMenu("Theme", "Dark")
        openPanel()
        XCTAssertLessThan(brightness(of: prefixField), 0.4)
        app.typeKey(.escape, modifierFlags: [])

        pickMenu("Theme", "Light")
        openPanel()
        XCTAssertGreaterThan(brightness(of: prefixField), 0.7)
    }

    func testSettingsSurviveRelaunchButMemoryPasswordDoesNot() {
        launch()
        pickMenu("Theme", "Dark")
        pickMenu("Language", "简体中文")
        openPanel()
        fill(password: "test", key: "github")
        prefixField.click()
        prefixField.typeText("pre-")
        suffixField.click()
        suffixField.typeText("-suf")
        lengthButton.click()
        app.menuItems["08位"].click()

        app.terminate()
        app.launchArguments.append("--keep-defaults")
        app.launch()
        openPanel()
        XCTAssertEqual(prefixField.value as? String, "pre-")
        XCTAssertEqual(suffixField.value as? String, "-suf")
        XCTAssertEqual(lengthButton.value as? String, "08位")
        XCTAssertEqual(passwordField.placeholderValue, "记忆密码")
        XCTAssertLessThan(brightness(of: prefixField), 0.4)
        XCTAssertEqual(passwordField.value as? String ?? "", "", "the memory password must not be restored")
        XCTAssertEqual(keyField.value as? String ?? "", "")
    }

    // MARK: - Accessibility

    func testAccessibilityNamesAndStates() {
        launch()
        XCTAssertEqual(statusItem.label, "FlowerPassword")
        openPanel()
        XCTAssertEqual(passwordField.label, "Memory Password")
        XCTAssertEqual(lengthButton.label, "Password Length")
        XCTAssertEqual(app.buttons["website"].label, "Official Website")
        XCTAssertFalse(generateButton.isEnabled, "nothing to generate yet")
        fill(password: "test", key: "github")
        XCTAssertTrue(generateButton.isEnabled)
    }

    func testPanelPassesAccessibilityAuditInLightTheme() throws {
        launch()
        pickMenu("Theme", "Light")
        try auditPanel()
    }

    func testPanelPassesAccessibilityAuditInDarkTheme() throws {
        launch()
        pickMenu("Theme", "Dark")
        try auditPanel()
    }

    /// Audits with the caret in a field and again with focus on a button,
    /// since the field editor changes what the panel exposes.
    private func auditPanel() throws {
        // The contrast audit samples rendered pixels; on a 1x display (CI's
        // virtual screen) anti-aliasing keeps thin 12pt strokes from ever
        // reaching their color, so any small text fails. Retina runs check it.
        let types: XCUIAccessibilityAuditType = (NSScreen.main?.backingScaleFactor ?? 1) >= 2
            ? .all : XCUIAccessibilityAuditType.all.subtracting(.contrast)
        openPanel()
        fill(password: "test", key: "github")
        try app.performAccessibilityAudit(for: types, Self.ignoreKnownIssue)
        keyField.typeKey(.tab, modifierFlags: [])
        try app.performAccessibilityAudit(for: types, Self.ignoreKnownIssue)
    }

    /// Issues that are not the app's to fix:
    /// - elements already gone when reported: transient system UI such as the
    ///   input-source caret bubble or a tooltip (this also covers the
    ///   parent/child mismatch AppKit's field editor reports while editing);
    /// - a Touch Bar element AppKit exposes for the menu bar, present before any window opens;
    /// - the 22pt bold brand-blue title, which as large text meets WCAG AA's 3:1.
    private static func ignoreKnownIssue(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        guard let element = issue.element else { return true }
        if element.elementType == .touchBar { return true }
        return issue.auditType == .contrast && element.value as? String == "Flower Password"
    }

    // MARK: - Quit

    func testQuitAsksForConfirmation() {
        launch()
        pickMenu("Quit")
        app.dialogs.firstMatch.buttons["Cancel"].click()
        XCTAssertNotEqual(app.state, .notRunning)

        pickMenu("Quit")
        app.dialogs.firstMatch.buttons["Quit"].click()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
    }

    // MARK: - Helpers

    private func launch() {
        continueAfterFailure = false
        // ponytail: restores plain text only; richer clipboard contents are lost on local runs.
        let savedClipboard = NSPasteboard.general.string(forType: .string)
        NSPasteboard.general.clearContents()
        addTeardownBlock { @MainActor [app = XCUIApplication()] in
            app.terminate()
            NSPasteboard.general.clearContents()
            if let savedClipboard {
                NSPasteboard.general.setString(savedClipboard, forType: .string)
            }
        }

        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en-US)"]
        app.launch()
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
    }

    private func openPanel() {
        statusItem.click()
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3))
    }

    private func fill(password: String, key: String) {
        passwordField.click()
        passwordField.typeText(password)
        keyField.click()
        keyField.typeText(key)
    }

    /// Right-clicks the status item and walks the given menu path.
    private func pickMenu(_ path: String...) {
        statusItem.rightClick()
        var scope: XCUIElement = app
        for title in path {
            let item = scope.menuItems[title].firstMatch
            XCTAssertTrue(item.waitForExistence(timeout: 3), "menu item \(title)")
            item.click()
            scope = item
        }
    }

    private func setPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Mean brightness (0...1) of an element's pixels, for telling the
    /// light theme from the dark one.
    private func brightness(of element: XCUIElement) -> CGFloat {
        let image = element.screenshot().image
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else {
            XCTFail("unreadable screenshot")
            return 0
        }
        var total: CGFloat = 0
        var count: CGFloat = 0
        for x in stride(from: 0, to: bitmap.pixelsWide, by: 4) {
            for y in stride(from: 0, to: bitmap.pixelsHigh, by: 4) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                total += color.brightnessComponent
                count += 1
            }
        }
        return count > 0 ? total / count : 0
    }

    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return condition()
    }
}
