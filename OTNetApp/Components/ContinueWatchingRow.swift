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

    private let cardWidth: CGFloat = 240
    private let cardHeight: CGFloat = 135

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(
                url: content.backdropURL ?? content.landscapeURL ?? content.posterURL,
                transaction: Transaction(animation: .easeInOut(duration: 0.25))
            ) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    ZStack {
                        LinearGradient(
                            colors: [OTNetTheme.card, OTNetTheme.muted.opacity(0.7)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(OTNetTheme.textTertiary)
                    }
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipped()

            // Bottom-fading scrim so the title + time remaining stay legible
            // over any artwork.
            LinearGradient(
                colors: [.clear, .black.opacity(0.15), .black.opacity(0.85)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 90)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            // Centered play affordance — more standard than the corner one.
            ZStack {
                Circle().fill(.black.opacity(0.45))
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .offset(x: 1)
            }
            .frame(width: 44, height: 44)
            .overlay(
                Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Title + time-remaining baked onto the artwork.
            VStack(alignment: .leading, spacing: 3) {
                Text(content.displayTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.6), radius: 3)
                if let remaining = remainingText {
                    Text(remaining)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.6), radius: 3)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            // Progress bar — drawn inside the clipped region so it inherits
            // the rounded bottom corners instead of poking straight across.
            ZStack(alignment: .leading) {
                Rectangle().fill(.white.opacity(0.22))
                GeometryReader { geo in
                    Rectangle()
                        .fill(OTNetTheme.primary)
                        .frame(width: geo.size.width * CGFloat(progress.fractionComplete))
                }
            }
            .frame(height: 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: OTNetTheme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: OTNetTheme.cornerRadius)
                .strokeBorder(OTNetTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 8, y: 5)
    }

    private var remainingText: String? {
        let remaining = max(0, progress.duration - progress.position)
        guard remaining > 0 else { return nil }
        let totalMin = Int(remaining.rounded(.up)) / 60
        if totalMin >= 60 {
            let h = totalMin / 60, m = totalMin % 60
            return m == 0 ? "\(h)h left" : "\(h)h \(m)m left"
        }
        if totalMin >= 1 { return "\(totalMin)m left" }
        let secs = Int(remaining.rounded(.up))
        return secs > 0 ? "\(secs)s left" : nil
    }
}
