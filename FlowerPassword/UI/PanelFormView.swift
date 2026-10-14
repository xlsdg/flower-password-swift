import AppKit
import Observation

import FlowerPasswordCore
import FlowerPasswordDomain

/// Actions the form triggers on its AppKit host.
struct PanelActions {
    var copyAndHide: (String) -> Void
    var hide: () -> Void
}

/// The 300×334 form: memory password and distinction code inputs, a joined
/// generate-button + length-select row, a joined prefix/suffix row, and
/// three bulleted hints.
///
/// Reads `Settings` and `Session` through `withObservationTracking`, funneling every
/// change (text, generated code, theme, focus token) through a single
/// `render()` pass; edits flow back via `NSTextFieldDelegate`.
final class PanelFormView: NSView, NSTextFieldDelegate {
    private let settings: Settings
    private let session: Session
    private let actions: PanelActions

    private let titleLabel = NSTextField(labelWithString: "")
    private let closeButton = PanelButton()
    private let passwordField = FocusReportingSecureTextField()
    private let keyField = FocusReportingTextField()
    private let prefixField = FocusReportingTextField()
    private let suffixField = FocusReportingTextField()
    private let passwordContainer = NSView()
    private let keyContainer = NSView()
    private let prefixContainer = NSView()
    private let suffixContainer = NSView()
    private let generateButton = HoverButton()
    private let lengthButton = PanelButton()
    private let lengthDivider = NSView()
    private let hintPasswordLabel = NSTextField(wrappingLabelWithString: "")
    private let hintKeyLabel = NSTextField(wrappingLabelWithString: "")
    private let websiteLabel = NSTextField(labelWithString: "")
    private let websiteButton = LinkButton()

    private var focusedField: FocusField?
    private var isHoveringGenerate = false
    private var lastFocusToken: Int

    private static let websiteURL = URL(string: "https://flowerpassword.com/")!
    private static let brandName = "Flower Password"

    /// UI tests measure contrast against the palette itself rather than
    /// whatever happens to sit behind the translucent panel.
    private static let forcesOpaqueBackground = ProcessInfo.processInfo.arguments.contains("--ui-testing")

    init(settings: Settings, session: Session, actions: PanelActions) {
        self.settings = settings
        self.session = session
        self.actions = actions
        self.lastFocusToken = session.focusToken
        super.init(
            frame: NSRect(x: 0, y: 0, width: PanelMetrics.width, height: PanelMetrics.height))
        wantsLayer = true
        // Fills the effectView's full bounds (see PanelController), so it
        // must mirror the panel's rounded corners or its opaque background
        // squares off the effectView's masked corners.
        layer?.cornerRadius = PanelMetrics.cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true

        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.stringValue = Self.brandName

        configureButton(closeButton, action: #selector(closePressed))
        configureButton(generateButton, action: #selector(generatePressed), cornerMask: Self.leftCorners)
        configureButton(lengthButton, action: #selector(lengthPressed), cornerMask: Self.rightCorners)
        generateButton.onHover = { [weak self] hovering in
            self?.isHoveringGenerate = hovering
            self?.render()
        }
        lengthDivider.wantsLayer = true

        configureField(passwordField, in: passwordContainer, cornerMask: Self.allCorners, focus: .password)
        configureField(keyField, in: keyContainer, cornerMask: Self.allCorners, focus: .key)
        configureField(prefixField, in: prefixContainer, cornerMask: Self.leftCorners, focus: .prefix)
        configureField(suffixField, in: suffixContainer, cornerMask: Self.rightCorners, focus: .suffix)
        for (field, name) in [
            (passwordField, String(localized: .memoryPassword)), (keyField, String(localized: .distinctionCode)),
            (prefixField, String(localized: .prefix)), (suffixField, String(localized: .suffix)),
        ] as [(NSTextField, String)] {
            field.placeholderString = name
            // Placeholders vanish once a field has text; the label keeps it named.
            field.setAccessibilityLabel(name)
        }

        // VoiceOver reads the visual titles ("×", the masked code, a bare
        // domain) as gibberish; these buttons need stable spoken names.
        closeButton.toolTip = String(localized: .close)
        closeButton.setAccessibilityLabel(String(localized: .close))
        generateButton.setAccessibilityLabel(String(localized: .generatePassword))
        lengthButton.setAccessibilityLabel(String(localized: .passwordLength))
        websiteButton.setAccessibilityLabel(String(localized: .officialWebsite))
        websiteButton.toolTip = Self.websiteURL.absoluteString

        hintPasswordLabel.stringValue = "· " + String(localized: .memoryPasswordHint)
        hintKeyLabel.stringValue = "· " + String(localized: .distinctionCodeHint)
        websiteLabel.stringValue = "· " + String(localized: .officialWebsiteHint)

        for label in [hintPasswordLabel, hintKeyLabel, websiteLabel] {
            label.font = .systemFont(ofSize: 12)
            label.isSelectable = false
        }
        configureButton(websiteButton, action: #selector(websitePressed))

        for (view, id) in [
            (passwordField, "password"), (keyField, "key"), (prefixField, "prefix"),
            (suffixField, "suffix"), (generateButton, "generate"), (lengthButton, "length"),
            (closeButton, "close"), (websiteButton, "website"),
        ] as [(NSView, String)] {
            view.setAccessibilityIdentifier(id)
        }

        for view in [
            titleLabel, closeButton, passwordContainer, keyContainer, generateButton,
            lengthButton, lengthDivider, prefixContainer, suffixContainer,
            hintPasswordLabel, hintKeyLabel, websiteLabel, websiteButton,
        ] as [NSView] {
            addSubview(view)
        }

        let tabOrder: [NSView] = [
            passwordField, keyField, generateButton, lengthButton, prefixField, suffixField, websiteButton,
            closeButton,
        ]
        for (view, next) in zip(tabOrder, tabOrder.dropFirst() + [passwordField]) {
            view.nextKeyView = next
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(accessibilityDisplayOptionsChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        observeState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // A window without an initialFirstResponder rebuilds the key view loop on
    // first display, discarding the explicit loop above.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.initialFirstResponder = passwordField
        // Never drawn on the borderless panel; VoiceOver announces it as the window name.
        window?.title = Self.brandName
    }

    // Top-down manual layout; a fixed-size panel needs no Auto Layout.
    override var isFlipped: Bool { true }

    // MARK: - Subview configuration

    private static let allCorners: CACornerMask = [
        .layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner,
    ]
    private static let leftCorners: CACornerMask = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
    private static let rightCorners: CACornerMask = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]

    private func configureButton(_ button: PanelButton, action: Selector, cornerMask: CACornerMask? = nil) {
        button.isBordered = false
        button.wantsLayer = true
        if let cornerMask {
            button.layer?.cornerRadius = 4
            button.layer?.maskedCorners = cornerMask
        }
        button.target = self
        button.action = action
    }

    private func configureField(
        _ field: NSTextField, in container: NSView, cornerMask: CACornerMask,
        focus: FocusField
    ) {
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 14)
        field.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.delegate = self
        let onFocus = { [weak self] in
            self?.focusedField = focus
            self?.render()
        }
        (field as? FocusReportingTextField)?.onFocus = onFocus
        (field as? FocusReportingSecureTextField)?.onFocus = onFocus

        container.wantsLayer = true
        container.layer?.cornerRadius = 4
        container.layer?.maskedCorners = cornerMask
        container.layer?.borderWidth = 1
        container.addSubview(field)
    }

    // MARK: - Rendering

    /// Re-runs `render()` on every Settings or Session mutation. `onChange` fires on
    /// willSet, so the re-render is deferred a tick to read the new values.
    private func observeState() {
        withObservationTracking {
            render()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeState()
            }
        }
    }

    /// The single refresh path: colors, field values, button titles, focus,
    /// and geometry all update here, for the current theme.
    private func render() {
        let palette = Palette.resolve(for: effectiveAppearance)

        // Translucency lets the desktop erode text contrast; Reduce
        // Transparency (implied by Increase Contrast) makes the tint solid.
        let opaque = Self.forcesOpaqueBackground
            || NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        layer?.backgroundColor = (opaque ? palette.windowTint.withAlphaComponent(1) : palette.windowTint).cgColor
        titleLabel.textColor = palette.textPrimary

        closeButton.attributedTitle = Self.buttonTitle("×", color: palette.buttonText)
        closeButton.layer?.backgroundColor = palette.buttonPrimary.cgColor
        setValueIfChanged(passwordField, session.password)
        setValueIfChanged(keyField, session.key)
        setValueIfChanged(prefixField, settings.prefix)
        setValueIfChanged(suffixField, settings.suffix)
        for field in [passwordField, keyField, prefixField, suffixField] {
            field.textColor = palette.inputText
        }
        for (container, focus) in fieldContainers {
            container.layer?.backgroundColor = palette.inputBackground.cgColor
            container.layer?.borderColor =
                (focusedField == focus ? palette.textPrimary : palette.border).cgColor
        }
        // A focused prefix must draw its highlighted border over the suffix
        // in the -1pt overlap (the suffix wins otherwise, being added later).
        // zPosition only reorders compositing: re-inserting the view instead
        // would reset the caret of a field being typed into.
        prefixContainer.layer?.zPosition = focusedField == .prefix ? 1 : 0

        generateButton.attributedTitle = Self.buttonTitle(
            generateButtonLabel(), color: palette.buttonText)
        generateButton.layer?.backgroundColor =
            (isHoveringGenerate ? palette.buttonPrimaryHover : palette.buttonPrimary).cgColor
        // Clicking does nothing until both inputs are filled; say so without dimming the brand button.
        generateButton.setAccessibilityEnabled(!session.generatedCode(using: settings).isEmpty)
        let length = lengthLabel(settings.passwordLength)
        lengthButton.attributedTitle = Self.buttonTitle(length, color: palette.buttonText)
        lengthButton.setAccessibilityValue(length)
        lengthButton.layer?.backgroundColor = palette.buttonPrimary.cgColor
        lengthDivider.layer?.backgroundColor = palette.buttonText.cgColor

        for label in [hintPasswordLabel, hintKeyLabel, websiteLabel] {
            label.textColor = palette.textSecondary
        }
        websiteButton.attributedTitle = NSAttributedString(
            string: Self.websiteURL.host() ?? Self.websiteURL.absoluteString,
            attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: palette.link])

        if session.focusToken != lastFocusToken {
            lastFocusToken = session.focusToken
            window?.makeFirstResponder(field(for: session.focusField))
        }

        layoutForm()
    }

    /// Editing a field echoes its own value back through observation; only
    /// external writes (URL prefill) may replace the text, otherwise
    /// the caret would jump on every keystroke.
    private func setValueIfChanged(_ field: NSTextField, _ value: String) {
        if field.stringValue != value {
            field.stringValue = value
        }
    }

    private var fieldContainers: [(NSView, FocusField)] {
        [
            (passwordContainer, .password), (keyContainer, .key),
            (prefixContainer, .prefix), (suffixContainer, .suffix),
        ]
    }

    private func field(for focus: FocusField) -> NSTextField {
        switch focus {
        case .password: passwordField
        case .key: keyField
        case .prefix: prefixField
        case .suffix: suffixField
        }
    }

    /// Shows the localized call-to-action until both inputs are filled,
    /// then the masked code — revealed in full while hovered.
    private func generateButtonLabel() -> String {
        let code = session.generatedCode(using: settings)
        if code.isEmpty {
            return String(localized: .generatePassword)
        }
        return isHoveringGenerate ? code : TextUtilities.maskPassword(code)
    }

    private func lengthLabel(_ length: Int) -> String {
        String(localized: .passwordLengthValue(length.formatted(.number.precision(.integerLength(2)))))
    }

    private static func buttonTitle(_ string: String, color: NSColor) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byTruncatingTail
        return NSAttributedString(
            string: string,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: color,
                .paragraphStyle: style,
            ])
    }

    @objc private func accessibilityDisplayOptionsChanged() {
        render()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        render()
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        layoutForm()
    }

    private func layoutForm() {
        let width = bounds.width - PanelLayout.Metrics.pad * 2
        let hintBounds = NSRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude)
        func hintHeight(_ label: NSTextField) -> CGFloat {
            label.cell?.cellSize(forBounds: hintBounds).height ?? 0
        }
        let measurements = PanelLayout.Measurements(
            titleHeight: titleLabel.cell?.cellSize.height ?? 0,
            hintPasswordHeight: hintHeight(hintPasswordLabel),
            hintKeyHeight: hintHeight(hintKeyLabel),
            websiteLabelSize: websiteLabel.cell?.cellSize ?? .zero,
            websiteLabelTextWidth: websiteLabel.attributedStringValue.size().width,
            websiteButtonSize: websiteButton.cell?.cellSize ?? .zero,
            websiteButtonTextWidth: websiteButton.attributedTitle.size().width)
        let frames = PanelLayout.place(width: bounds.width, measurements: measurements)

        titleLabel.frame = frames.title
        closeButton.frame = frames.close
        generateButton.frame = frames.generate
        lengthButton.frame = frames.length
        lengthDivider.frame = frames.lengthDivider
        hintPasswordLabel.frame = frames.hintPassword
        hintKeyLabel.frame = frames.hintKey
        websiteLabel.frame = frames.websiteLabel
        websiteButton.frame = frames.websiteButton
        for (field, container, frame) in [
            (passwordField, passwordContainer, frames.password),
            (keyField, keyContainer, frames.key),
            (prefixField, prefixContainer, frames.prefix),
            (suffixField, suffixContainer, frames.suffix),
        ] as [(NSTextField, NSView, CGRect)] {
            container.frame = frame
            field.frame = PanelLayout.fieldFrame(
                in: frame, fieldHeight: field.cell?.cellSize.height ?? 0)
        }
    }

    // MARK: - Actions

    @objc private func closePressed() {
        actions.hide()
    }

    @objc private func websitePressed() {
        NSWorkspace.shared.open(Self.websiteURL)
    }

    @objc private func generatePressed() {
        generateAndCopy()
    }

    private func generateAndCopy() {
        let code = session.generatedCode(using: settings)
        guard !code.isEmpty else { return }
        actions.copyAndHide(code)
    }

    /// Mimics an NSPopUpButton: the checked, currently-selected length pops
    /// up positioned over the button.
    @objc private func lengthPressed() {
        let menu = NSMenu()
        var selectedItem: NSMenuItem?
        for length in PasswordLength.range {
            let item = NSMenuItem(
                title: lengthLabel(length), action: #selector(lengthSelected(_:)), keyEquivalent: "")
            item.target = self
            item.tag = length
            item.state = length == settings.passwordLength ? .on : .off
            if length == settings.passwordLength { selectedItem = item }
            menu.addItem(item)
        }
        menu.popUp(positioning: selectedItem, at: .zero, in: lengthButton)
    }

    @objc private func lengthSelected(_ sender: NSMenuItem) {
        settings.passwordLength = sender.tag
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        switch field {
        case passwordField: session.password = field.stringValue
        case keyField: session.key = field.stringValue
        case prefixField: settings.prefix = field.stringValue
        case suffixField: settings.suffix = field.stringValue
        default: break
        }
    }

    /// Focus gain is reported by the fields themselves (`onFocus`); focus
    /// loss only surfaces here, when the field editor ends editing.
    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField,
            let focus = fieldContainers.first(where: { $0.0 == field.superview })?.1,
            focusedField == focus
        else { return }
        focusedField = nil
        render()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        // Esc in a field editor would otherwise trigger word completion.
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            actions.hide()
            return true
        }
        if control === keyField, selector == #selector(NSResponder.insertNewline(_:)) {
            generateAndCopy()
            return true
        }
        return false
    }
}
