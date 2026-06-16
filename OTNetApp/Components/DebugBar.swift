import SwiftUI

#if DEBUG
struct DebugBar: View {
    let rowCount: Int
    let itemCount: Int
    let lastError: String?

    var body: some View {
        HStack(spacing: 12) {
            Text("rows: \(rowCount)").monospaced()
            Text("items: \(itemCount)").monospaced()
            if let err = lastError {
                Text(err).foregroundStyle(.red).lineLimit(1)
            }
            Spacer()
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.6))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.3))
    }
}
#endif
