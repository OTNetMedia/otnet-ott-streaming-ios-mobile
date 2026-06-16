import SwiftUI

struct StatePlaceholder: View {
    enum Mode {
        case loading
        case empty(String)
        case error(String, retry: () -> Void)
    }

    let mode: Mode

    var body: some View {
        VStack(spacing: 16) {
            switch mode {
            case .loading:
                ProgressView().tint(OTNetTheme.textSecondary)
                Text("Loading…").foregroundStyle(OTNetTheme.textSecondary)
            case .empty(let msg):
                Image(systemName: "tray")
                    .font(.largeTitle)
                    .foregroundStyle(OTNetTheme.textTertiary)
                Text(msg)
                    .foregroundStyle(OTNetTheme.textSecondary)
                    .multilineTextAlignment(.center)
            case .error(let msg, let retry):
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text(msg)
                    .foregroundStyle(OTNetTheme.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Retry", action: retry)
                    .buttonStyle(.borderedProminent)
                    .tint(OTNetTheme.primary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
