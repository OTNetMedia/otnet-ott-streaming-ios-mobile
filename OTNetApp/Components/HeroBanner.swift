import SwiftUI

struct HeroBanner: View {
    let items: [Content]
    @State private var index = 0
    private let timer = Timer.publish(every: 8, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView(selection: $index) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                NavigationLink(value: item) {
                    HeroSlide(item: item)
                }
                .buttonStyle(.plain)
                .tag(i)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .frame(height: 460)
        .onReceive(timer) { _ in
            guard items.count > 1 else { return }
            withAnimation { index = (index + 1) % items.count }
        }
    }
}

private struct HeroSlide: View {
    let item: Content

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: item.landscapeURL ?? item.posterURL) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle().fill(OTNetTheme.card)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            LinearGradient(
                colors: [.clear, OTNetTheme.background.opacity(0.6), OTNetTheme.background],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 12) {
                if let url = item.titleImageURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().aspectRatio(contentMode: .fit)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(height: 80)
                } else {
                    Text(item.displayTitle)
                        .font(.largeTitle).bold()
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 6)
                }
                if let synopsis = item.description, !synopsis.isEmpty {
                    Text(synopsis)
                        .font(.subheadline)
                        .foregroundStyle(OTNetTheme.textSecondary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    Label("Play", systemImage: "play.fill")
                        .bold()
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(OTNetTheme.primary, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                    if let rating = item.ageRating {
                        AgeRatingBadge(rating: rating)
                    }
                }
            }
            .padding(20)
        }
        .clipped()
    }
}
