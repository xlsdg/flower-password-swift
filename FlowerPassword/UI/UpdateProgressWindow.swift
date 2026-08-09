import SwiftUI

struct UpdateProgressWindow: View {
    let progress: DownloadProgress
    let l10n: L10n

    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress.value, total: 1.0)
                .progressViewStyle(.linear)

            Text(l10n.updateDownloading)
                .foregroundColor(.secondary)

            if progress.value > 0 {
                Text("\(Int(progress.value * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}
