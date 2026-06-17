import SwiftUI

struct ContinueWatchingRow: View {
    let items: [WatchProgress]
    let resolve: (WatchProgress) -> Content?
    /// Fires when a tile is tapped. Receives the resolved Content and the
    /// position (in seconds) the viewer left off at — the caller should
    /// present a player seeded with that startAt.
    var onResume: (Content, Double) -> Void

    private var pairs: [(WatchProgress, Content)] {
        items.compactMap { p in
            guard let c = resolve(p) else { return nil }
            return (p, c)
        }
    }

    var body: some View {
        if pairs.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Continue Watching")
                    .font(.title3).bold()
                    .foregroundStyle(OTNetTheme.textPrimary)
                    .padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: OTNetTheme.cardGap) {
                        ForEach(pairs, id: \.0.id) { progress, content in
                            Button {
                                onResume(content, progress.position)
                            } label: {
                                ContinueWatchingCard(progress: progress, content: content)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

private struct ContinueWatchingCard: View {
    let progress: WatchProgress
    let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: content.landscapeURL ?? content.posterURL,
                           transaction: Transaction(animation: .easeInOut)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Rectangle().fill(OTNetTheme.card)
                            .overlay(
                                Image(systemName: "play.rectangle")
                                    .foregroundStyle(OTNetTheme.textTertiary)
                            )
                    }
                }
                .frame(width: 240, height: 135)
                .clipShape(RoundedRectangle(cornerRadius: OTNetTheme.cornerRadius))

                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 60)
                .clipShape(
                    RoundedRectangle(cornerRadius: OTNetTheme.cornerRadius)
                )

                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4)
                    Spacer()
                    if let remaining = remainingMinutes {
                        Text(remaining)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.55), in: Capsule())
                    }
                }
                .padding(10)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(.white.opacity(0.25))
                        Rectangle().fill(OTNetTheme.primary)
                            .frame(width: geo.size.width * CGFloat(progress.fractionComplete))
                    }
                    .frame(height: 3)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .frame(width: 240, height: 135)
            .overlay(
                RoundedRectangle(cornerRadius: OTNetTheme.cornerRadius)
                    .strokeBorder(OTNetTheme.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 6, y: 4)

            Text(content.displayTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(OTNetTheme.textPrimary)
                .lineLimit(1)
                .frame(width: 240, alignment: .leading)
        }
        .frame(width: 240)
    }

    private var remainingMinutes: String? {
        let remaining = max(0, progress.duration - progress.position)
        guard remaining > 0 else { return nil }
        let mins = Int(remaining.rounded(.up)) / 60
        let secs = Int(remaining.rounded(.up)) % 60
        if mins >= 1 { return "\(mins)m left" }
        return secs > 0 ? "\(secs)s left" : nil
    }
}
