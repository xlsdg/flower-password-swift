import AppKit
import Observation

import FlowerPasswordCore

/// Actions the form triggers on its AppKit host.
@MainActor
struct PanelActions {
    var copyAndHide: (String) -> Void
    var hide: () -> Void
}

/// The 300×334 form: memory password and distinction code inputs, a joined
/// generate-button + length-select row, a joined prefix/suffix row, and
/// three bulleted hints.
///
/// Reads `AppState` through `withObservationTracking`, funneling every
/// change (text, generated code, language, theme, focus token) through a
/// single `render()` pass; edits flow back via `NSTextFieldDelegate`.
final class PanelFormView: NSView, NSTextFieldDelegate {
    private let state: AppState
    private let actions: PanelActions

    private let titleLabel = NSTextField(labelWithString: "")
    private let closeButton = NSButton()
    private let passwordField = FocusReportingSecureTextField()
    private let keyField = FocusReportingTextField()
    private let prefixField = FocusReportingTextField()
    private let suffixField = FocusReportingTextField()
    private let passwordContainer = NSView()
    private let keyContainer = NSView()
    private let prefixContainer = NSView()
    private let suffixContainer = NSView()
    private let generateButton = HoverButton()
    private let lengthButton = NSButton()
    private let lengthDivider = NSView()
    private let hintPasswordLabel = NSTextField(wrappingLabelWithString: "")
    private let hintKeyLabel = NSTextField(wrappingLabelWithString: "")
    private let websiteView = NSTextView()

    private var focusedField: AppState.FocusField?
    private var isHoveringGenerate = false
    private var lastFocusToken: Int

    private static let websiteURL = URL(string: "https://flowerpassword.com/")!

    init(state: AppState, actions: PanelActions) {
        self.state = state
        self.actions = actions
        self.lastFocusToken = state.focusToken
        super.init(
            frame: NSRect(x: 0, y: 0, width: PanelMetrics.width, height: PanelMetrics.height))
        wantsLayer = true

        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)

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

        for label in [hintPasswordLabel, hintKeyLabel] {
            label.font = .systemFont(ofSize: 12)
            label.isSelectable = false
        }

        websiteView.isEditable = false
        websiteView.isSelectable = true
        websiteView.drawsBackground = false
        websiteView.textContainerInset = .zero
        websiteView.textContainer?.lineFragmentPadding = 0

        for view in [
            titleLabel, closeButton, passwordContainer, keyContainer, generateButton,
            lengthButton, lengthDivider, prefixContainer, suffixContainer,
            hintPasswordLabel, hintKeyLabel, websiteView,
        ] as [NSView] {
            addSubview(view)
        }

        passwordField.nextKeyView = keyField
        keyField.nextKeyView = prefixField
        prefixField.nextKeyView = suffixField
        suffixField.nextKeyView = passwordField

        observeState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // Top-down manual layout; a fixed-size panel needs no Auto Layout.
    override var isFlipped: Bool { true }

    // MARK: - Subview configuration

    private static let allCorners: CACornerMask = [
        .layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner,
    ]
    private static let leftCorners: CACornerMask = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
    private static let rightCorners: CACornerMask = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]

    private func configureButton(_ button: NSButton, action: Selector, cornerMask: CACornerMask? = nil) {
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
        focus: AppState.FocusField
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

    /// Re-runs `render()` on every AppState mutation. `onChange` fires on
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

    /// The single refresh path: strings, colors, field values, focus, and
    /// geometry all update here, for the current theme and language.
    private func render() {
        let palette = Palette.palette(for: effectiveAppearance)
        let l10n = state.l10n

        layer?.backgroundColor = palette.windowTint.cgColor

        titleLabel.stringValue = l10n.appTitle
        titleLabel.textColor = palette.textPrimary

        closeButton.attributedTitle = Self.buttonTitle("×", color: palette.buttonText)
        closeButton.layer?.backgroundColor = palette.buttonPrimary.cgColor
        closeButton.toolTip = l10n.close
        // VoiceOver reads the visual titles ("×", the masked code) as
        // gibberish; both buttons need stable spoken names.
        closeButton.setAccessibilityLabel(l10n.close)
        generateButton.setAccessibilityLabel(l10n.generateButton)

        passwordField.placeholderString = l10n.passwordPlaceholder
        keyField.placeholderString = l10n.keyPlaceholder
        prefixField.placeholderString = l10n.prefixPlaceholder
        suffixField.placeholderString = l10n.suffixPlaceholder
        setValueIfChanged(passwordField, state.password)
        setValueIfChanged(keyField, state.key)
        setValueIfChanged(prefixField, state.prefix)
        setValueIfChanged(suffixField, state.suffix)
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
        addSubview(
            prefixContainer,
            positioned: focusedField == .prefix ? .above : .below,
            relativeTo: suffixContainer)

        generateButton.attributedTitle = Self.buttonTitle(
            generateButtonLabel(l10n), color: palette.buttonText)
        generateButton.layer?.backgroundColor =
            (isHoveringGenerate ? palette.buttonPrimaryHover : palette.buttonPrimary).cgColor
        lengthButton.attributedTitle = Self.buttonTitle(
            lengthLabel(state.passwordLength), color: palette.buttonText)
        lengthButton.layer?.backgroundColor = palette.buttonPrimary.cgColor
        lengthDivider.layer?.backgroundColor = palette.buttonText.cgColor

        hintPasswordLabel.stringValue = "· " + l10n.hintPassword
        hintKeyLabel.stringValue = "· " + l10n.hintKey
        for label in [hintPasswordLabel, hintKeyLabel] {
            label.textColor = palette.textSecondary
        }
        websiteView.textStorage?.setAttributedString(websiteAttributed(l10n, palette: palette))
        websiteView.linkTextAttributes = [
            .foregroundColor: palette.link,
            .cursor: NSCursor.pointingHand,
        ]

        if state.focusToken != lastFocusToken {
            lastFocusToken = state.focusToken
            window?.makeFirstResponder(field(for: state.focusField))
        }

        layoutForm()
    }

    /// Editing a field echoes its own value back through observation; only
    /// external writes (clipboard prefill) may replace the text, otherwise
    /// the caret would jump on every keystroke.
    private func setValueIfChanged(_ field: NSTextField, _ value: String) {
        if field.stringValue != value {
            field.stringValue = value
        }
    }

    private var fieldContainers: [(NSView, AppState.FocusField)] {
        [
            (passwordContainer, .password), (keyContainer, .key),
            (prefixContainer, .prefix), (suffixContainer, .suffix),
        ]
    }

    private func field(for focus: AppState.FocusField) -> NSTextField {
        switch focus {
        case .password: passwordField
        case .key: keyField
        case .prefix: prefixField
        case .suffix: suffixField
        }
    }

    /// Shows the localized call-to-action until both inputs are filled,
    /// then the masked code — revealed in full while hovered.
    private func generateButtonLabel(_ l10n: L10n) -> String {
        let code = state.generatedCode
        if code.isEmpty {
            return l10n.generateButton
        }
        return isHoveringGenerate ? code : TextUtilities.maskPassword(code)
    }

    private func lengthLabel(_ length: Int) -> String {
        String(format: "%02d", length) + state.l10n.lengthUnit
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

    private func websiteAttributed(_ l10n: L10n, palette: Palette) -> NSAttributedString {
        let text = NSMutableAttributedString(
            string: "· " + l10n.hintWebsite,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: palette.textSecondary,
            ])
        text.append(
            NSAttributedString(
                string: Self.websiteURL.absoluteString,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12),
                    .link: Self.websiteURL,
                ]))
        return text
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        render()
    }

    // MARK: - Layout

    private enum Metrics {
        static let pad: CGFloat = 10
        static let spacing: CGFloat = 10
        static let rowHeight: CGFloat = 32
        static let fieldInset: CGFloat = 6
        static let closeSize: CGFloat = 16
        static let lengthWidth: CGFloat = 64
    }

    override func layout() {
        super.layout()
        layoutForm()
    }

    private func layoutForm() {
        let pad = Metrics.pad
        let width = bounds.width - pad * 2
        var y = pad

        let titleHeight = ceil(titleLabel.cell?.cellSize.height ?? 0)
        titleLabel.frame = NSRect(
            x: pad, y: y, width: width - Metrics.closeSize - 4, height: titleHeight)
        closeButton.frame = NSRect(
            x: pad + width - Metrics.closeSize,
            y: y + (titleHeight - Metrics.closeSize) / 2,
            width: Metrics.closeSize, height: Metrics.closeSize)
        y += titleHeight + Metrics.spacing

        layoutField(passwordField, in: passwordContainer, frame: NSRect(x: pad, y: y, width: width, height: Metrics.rowHeight))
        y += Metrics.rowHeight + Metrics.spacing
        layoutField(keyField, in: keyContainer, frame: NSRect(x: pad, y: y, width: width, height: Metrics.rowHeight))
        y += Metrics.rowHeight + Metrics.spacing

        let generateWidth = width - Metrics.lengthWidth
        generateButton.frame = NSRect(x: pad, y: y, width: generateWidth, height: Metrics.rowHeight)
        lengthButton.frame = NSRect(
            x: pad + generateWidth, y: y, width: Metrics.lengthWidth, height: Metrics.rowHeight)
        // Hairline divider between the button and the length select.
        lengthDivider.frame = NSRect(x: pad + generateWidth, y: y, width: 1, height: Metrics.rowHeight)
        y += Metrics.rowHeight + Metrics.spacing

        // -1pt overlap joins the two middle borders into a single hairline.
        let splitWidth = (width + 1) / 2
        layoutField(prefixField, in: prefixContainer, frame: NSRect(x: pad, y: y, width: splitWidth, height: Metrics.rowHeight))
        layoutField(suffixField, in: suffixContainer, frame: NSRect(x: pad + splitWidth - 1, y: y, width: splitWidth, height: Metrics.rowHeight))
        y += Metrics.rowHeight + Metrics.spacing

        for label in [hintPasswordLabel, hintKeyLabel] {
            let bounds = NSRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude)
            let height = ceil(label.cell?.cellSize(forBounds: bounds).height ?? 0)
            label.frame = NSRect(x: pad, y: y, width: width, height: height)
            y += height + Metrics.spacing
        }

        let websiteHeight = ceil(
            (websiteView.textStorage ?? NSTextStorage())
                .boundingRect(
                    with: NSSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading]
                ).height)
        websiteView.frame = NSRect(x: pad, y: y, width: width, height: websiteHeight)
    }

    private func layoutField(_ field: NSTextField, in container: NSView, frame: NSRect) {
        container.frame = frame
        let fieldHeight = ceil(field.cell?.cellSize.height ?? 0)
        field.frame = NSRect(
            x: Metrics.fieldInset,
            y: (frame.height - fieldHeight) / 2,
            width: frame.width - Metrics.fieldInset * 2,
            height: fieldHeight)
    }

    // MARK: - Actions

    @objc private func closePressed() {
        actions.hide()
    }

    @objc private func generatePressed() {
        generateAndCopy()
    }

    private func generateAndCopy() {
        let code = state.generatedCode
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
            item.state = length == state.passwordLength ? .on : .off
            if length == state.passwordLength { selectedItem = item }
            menu.addItem(item)
        }
        menu.popUp(positioning: selectedItem, at: .zero, in: lengthButton)
    }

    @objc private func lengthSelected(_ sender: NSMenuItem) {
        state.passwordLength = sender.tag
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        switch field {
        case passwordField: state.password = field.stringValue
        case keyField: state.key = field.stringValue
        case prefixField: state.prefix = field.stringValue
        case suffixField: state.suffix = field.stringValue
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

// MARK: - Field & button subclasses

/// Reports focus gain the moment the field becomes first responder (the
/// delegate's `controlTextDidEndEditing` covers focus loss).
private final class FocusReportingTextField: NSTextField {
    var onFocus: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocus?() }
        return accepted
    }
}

private final class FocusReportingSecureTextField: NSSecureTextField {
    var onFocus: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocus?() }
        return accepted
    }
}

/// Borderless button that reports mouse hover, for the hover-to-reveal
/// generated code and the hover background tint.
private final class HoverButton: NSButton {
    var onHover: ((Bool) -> Void)?
    private var hoverArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(
            rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHover?(false)
    }
}
