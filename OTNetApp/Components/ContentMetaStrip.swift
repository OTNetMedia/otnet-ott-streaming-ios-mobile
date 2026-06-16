import SwiftUI

struct ContentMetaStrip: View {
    let item: Content
    var includeContentType: Bool = false

    var body: some View {
        let parts = metaParts
        if !parts.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(parts.enumerated()), id: \.offset) { idx, part in
                    if idx > 0 {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(OTNetTheme.textSecondary.opacity(0.6))
                    }
                    part.view
                }
            }
            .lineLimit(1)
        }
    }

    private var metaParts: [MetaPart] {
        var parts: [MetaPart] = []
        if let rating = item.ratingValue, !rating.isEmpty {
            parts.append(.init(view: AnyView(
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text(rating)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(OTNetTheme.textPrimary)
                }
            )))
        }
        if let year = item.year {
            parts.append(.text(year))
        }
        if includeContentType, let t = item.contentType ?? item.type, !t.isEmpty {
            parts.append(.text(t.capitalized))
        }
        if let genre = item.primaryGenreName, !genre.isEmpty {
            parts.append(.text(genre))
        }
        if let studio = item.studioName, !studio.isEmpty {
            parts.append(.text(studio))
        }
        if let mode = item.monetizationLabel {
            parts.append(.init(view: AnyView(
                Text(mode)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(OTNetTheme.primary.opacity(0.85), in: Capsule())
            )))
        }
        return parts
    }
}

private struct MetaPart {
    let view: AnyView

    static func text(_ value: String) -> MetaPart {
        MetaPart(view: AnyView(
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(OTNetTheme.textSecondary)
        ))
    }
}
