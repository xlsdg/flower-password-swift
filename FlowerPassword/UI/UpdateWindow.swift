import SwiftUI

struct UpdateWindow: View {
    let currentVersion: String
    let newVersion: String
    let releaseNotes: String
    let l10n: L10n
    let onInstall: () -> Void
    let onSkip: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.updateWindowTitle)
                        .font(.title2.bold())
                    Text("\(currentVersion) → \(newVersion)")
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView {
                Text(.init(releaseNotes))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
            }
            .frame(height: 300)

            HStack(spacing: 12) {
                Button(l10n.updateWindowSkip) {
                    dismiss()
                    onSkip()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(l10n.updateWindowInstall) {
                    dismiss()
                    onInstall()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}
