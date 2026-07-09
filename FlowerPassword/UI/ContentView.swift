import SwiftUI

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
struct ContentView: View {
    @Bindable var state: AppState
    let actions: PanelActions

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedField: AppState.FocusField?
    @State private var isHoveringGenerate = false

    private var palette: Palette { .palette(for: colorScheme) }
    private var l10n: L10n { .strings(for: state.effectiveLanguage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            formField(.password) {
                SecureField(l10n.passwordPlaceholder, text: $state.password)
            }

            formField(.key) {
                TextField(l10n.keyPlaceholder, text: $state.key)
                    .onSubmit(generateAndCopy)
            }

            controls

            splitFields

            hint(l10n.hintPassword)
            hint(l10n.hintKey)
            websiteHint

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: PanelMetrics.width, height: PanelMetrics.height, alignment: .top)
        .background(palette.windowTint)
        .onChange(of: state.focusToken) {
            focusedField = state.focusField
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            Text(l10n.appTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(palette.textPrimary)
            Spacer(minLength: 0)
            Button(action: actions.hide) {
                Text("×")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.buttonText)
                    .frame(width: 16, height: 16)
                    .background(palette.buttonPrimary)
            }
            .buttonStyle(.plain)
            .help(l10n.close)
        }
    }

    // MARK: - Inputs

    private func formField(
        _ field: AppState.FocusField,
        corners: RectangleCornerRadii = .init(
            topLeading: 4, bottomLeading: 4, bottomTrailing: 4, topTrailing: 4
        ),
        @ViewBuilder content: () -> some View
    ) -> some View {
        let shape = UnevenRoundedRectangle(cornerRadii: corners)
        return content()
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .foregroundStyle(palette.inputText)
            .focused($focusedField, equals: field)
            .padding(.horizontal, 6)
            .frame(height: 32)
            .frame(maxWidth: .infinity)
            .background(shape.fill(palette.inputBackground))
            .overlay(
                shape.strokeBorder(
                    focusedField == field ? palette.textPrimary : palette.border,
                    lineWidth: 1
                )
            )
    }

    private var splitFields: some View {
        // spacing -1 overlaps the two middle borders into a single hairline.
        HStack(spacing: -1) {
            formField(.prefix, corners: .init(topLeading: 4, bottomLeading: 4)) {
                TextField(l10n.prefixPlaceholder, text: $state.prefix)
            }
            .zIndex(focusedField == .prefix ? 1 : 0)

            formField(.suffix, corners: .init(bottomTrailing: 4, topTrailing: 4)) {
                TextField(l10n.suffixPlaceholder, text: $state.suffix)
            }
        }
    }

    // MARK: - Generate row

    private var controls: some View {
        HStack(spacing: 0) {
            Button(action: generateAndCopy) {
                Text(generateButtonLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.buttonText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(isHoveringGenerate ? palette.buttonPrimaryHover : palette.buttonPrimary)
                    .clipShape(
                        UnevenRoundedRectangle(cornerRadii: .init(topLeading: 4, bottomLeading: 4))
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isHoveringGenerate = $0 }

            lengthSelect
        }
    }

    /// Shows the localized call-to-action until both inputs are filled,
    /// then the masked code — revealed in full while hovered.
    private var generateButtonLabel: String {
        let code = state.generatedCode
        if code.isEmpty {
            return l10n.generateButton
        }
        return isHoveringGenerate ? code : TextUtilities.maskPassword(code)
    }

    private var lengthSelect: some View {
        Menu {
            Picker("", selection: $state.passwordLength) {
                ForEach(PasswordLength.range, id: \.self) { length in
                    Text(lengthLabel(length)).tag(length)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Text(lengthLabel(state.passwordLength))
                .font(.system(size: 12))
                .foregroundStyle(palette.buttonText)
                .frame(width: 64, height: 32)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .frame(width: 64, height: 32)
        .background(palette.buttonPrimary)
        .overlay(alignment: .leading) {
            // Hairline divider between the button and the length select.
            Rectangle()
                .fill(palette.buttonText)
                .frame(width: 1)
        }
        .clipShape(UnevenRoundedRectangle(cornerRadii: .init(bottomTrailing: 4, topTrailing: 4)))
    }

    private func lengthLabel(_ length: Int) -> String {
        String(format: "%02d", length) + l10n.lengthUnit
    }

    private func generateAndCopy() {
        let code = state.generatedCode
        guard !code.isEmpty else { return }
        actions.copyAndHide(code)
    }

    // MARK: - Hints

    private func hint(_ text: String) -> some View {
        Text("· " + text)
            .font(.system(size: 12))
            .foregroundStyle(palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let websiteURL = URL(string: "https://flowerpassword.com/")!

    private var websiteHint: some View {
        Text(websiteAttributed)
            .font(.system(size: 12))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var websiteAttributed: AttributedString {
        var label = AttributedString("· " + l10n.hintWebsite)
        label.foregroundColor = palette.textSecondary
        var link = AttributedString(Self.websiteURL.absoluteString)
        link.link = Self.websiteURL
        link.foregroundColor = palette.link
        return label + link
    }
}
