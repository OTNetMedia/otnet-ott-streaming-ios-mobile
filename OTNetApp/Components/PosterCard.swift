import SwiftUI

struct PosterCard: View {
    let url: URL?
    let title: String
    var ageRating: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .empty, .failure:
                        Rectangle().fill(OTNetTheme.card)
                            .overlay(
                                Image(systemName: "film")
                                    .foregroundStyle(OTNetTheme.textTertiary)
                            )
                    @unknown default:
                        Rectangle().fill(OTNetTheme.card)
                    }
                }
                .frame(width: 160, height: 240)
                .clipShape(RoundedRectangle(cornerRadius: OTNetTheme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: OTNetTheme.cornerRadius)
                        .strokeBorder(OTNetTheme.border, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)

                if let ageRating, !ageRating.isEmpty {
                    AgeRatingBadge(rating: ageRating)
                        .padding(8)
                }
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(OTNetTheme.textSecondary)
                .lineLimit(1)
                .frame(width: 160, alignment: .leading)
        }
        .frame(width: 160)
    }
}
