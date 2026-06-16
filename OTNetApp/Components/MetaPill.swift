import SwiftUI

struct MetaPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(OTNetTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(OTNetTheme.muted, in: RoundedRectangle(cornerRadius: 6))
    }
}
