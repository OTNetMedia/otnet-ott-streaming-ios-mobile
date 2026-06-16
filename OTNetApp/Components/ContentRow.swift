import SwiftUI

struct ContentRow: View {
    let row: HomepageRow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = row.genre?.name, !title.isEmpty {
                Text(title)
                    .font(.title3).bold()
                    .foregroundStyle(OTNetTheme.textPrimary)
                    .padding(.horizontal, 20)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: OTNetTheme.cardGap) {
                    ForEach(row.items ?? []) { item in
                        NavigationLink(value: item) {
                            if row.tileType == "landscape" {
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
                }
                .padding(.horizontal, 20)
            }
        }
    }
}
