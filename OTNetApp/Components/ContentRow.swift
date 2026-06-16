import SwiftUI

struct ContentRow: View {
    let row: HomepageRow

    private var category: Genre? {
        guard let ref = row.genre, let id = ref.id, !id.isEmpty else { return nil }
        return Genre(id: id, name: ref.name, slug: nil, order: nil, parent: nil, children: nil)
    }

    private var isLandscape: Bool { row.tileType == "landscape" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: OTNetTheme.cardGap) {
                    ForEach(row.items ?? []) { item in
                        NavigationLink(value: item) {
                            if isLandscape {
                                LandscapeCard(
                                    url: item.landscapeURL,
                                    title: item.displayTitle,
                                    ageRating: item.ageRating
                                )
                            } else {
                                PosterCard(
                                    url: item.posterURL,
                                    title: item.displayTitle,
                                    ageRating: item.ageRating
                                )
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if let category {
                        NavigationLink(value: category) {
                            ViewAllTile(isLandscape: isLandscape, title: category.name ?? "View all")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        if let title = row.genre?.name, !title.isEmpty {
            if let category {
                NavigationLink(value: category) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.title3).bold()
                            .foregroundStyle(OTNetTheme.textPrimary)
                        Spacer()
                        Text("View all")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(OTNetTheme.primary)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(OTNetTheme.primary)
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 20)
                }
                .buttonStyle(.plain)
            } else {
                Text(title)
                    .font(.title3).bold()
                    .foregroundStyle(OTNetTheme.textPrimary)
                    .padding(.horizontal, 20)
            }
        }
    }
}

private struct ViewAllTile: View {
    let isLandscape: Bool
    let title: String

    private var size: CGSize {
        isLandscape ? CGSize(width: 280, height: 158) : CGSize(width: 160, height: 240)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: OTNetTheme.cornerRadius)
                    .fill(OTNetTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: OTNetTheme.cornerRadius)
                            .strokeBorder(OTNetTheme.primary.opacity(0.5),
                                          style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    )

                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(OTNetTheme.primary.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: "arrow.right")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(OTNetTheme.primary)
                    }
                    Text("View all")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(OTNetTheme.textPrimary)
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(OTNetTheme.textSecondary)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                }
            }
            .frame(width: size.width, height: size.height)

            Text(" ")
                .font(.caption)
                .frame(width: size.width, alignment: .leading)
        }
        .frame(width: size.width)
    }
}
