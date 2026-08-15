import SwiftUI
import AppKit

private struct MarkdownTextView: NSViewRepresentable {
    let markdown: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = false
        textView.isRichText = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isSelectable = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        let attrStr = (try? AttributedString(markdown: markdown, options: options))
            ?? AttributedString(markdown)
        textView.textStorage?.setAttributedString(NSAttributedString(attrStr))
    }
}

struct UpdateWindow: View {
    let currentVersion: String
    let newVersion: String
    let releaseNotes: String
    let l10n: L10n
    let onInstall: () -> Void
    let onSkip: () -> Void

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

            MarkdownTextView(markdown: releaseNotes)
                .frame(height: 300)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)

            HStack(spacing: 12) {
                Button(l10n.updateWindowSkip) {
                    onSkip()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(l10n.updateWindowInstall) {
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
