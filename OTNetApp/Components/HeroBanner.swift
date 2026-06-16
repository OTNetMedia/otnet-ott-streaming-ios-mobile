import SwiftUI

struct HeroBanner: View {
    let items: [Content]
    @State private var index = 0
    @State private var playingItem: Content?
    private let timer = Timer.publish(every: 8, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $index) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    HeroSlide(item: item, isActive: i == index) {
                        playingItem = item
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 460)
        }
        .overlay(alignment: .bottom) {
            if items.count > 1 {
                PageDots(count: items.count, current: index)
                    .padding(.bottom, 8)
            }
        }
        .onReceive(timer) { _ in
            guard items.count > 1 else { return }
            withAnimation { index = (index + 1) % items.count }
        }
        .fullScreenCover(item: $playingItem) { item in
            PlayerView(content: item).ignoresSafeArea()
        }
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.white : Color.white.opacity(0.35))
                    .frame(width: i == current ? 18 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.2), value: current)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.35), in: Capsule())
    }
}

private struct HeroSlide: View {
    let item: Content
    let isActive: Bool
    let onPlay: () -> Void

    @EnvironmentObject private var myList: MyListStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var settingsStore: SettingsStore

    private var canUseList: Bool {
        !(settingsStore.settings?.viewerAuthNone ?? false) && auth.isSignedIn
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                NavigationLink(value: item) {
                    ZStack(alignment: .bottomLeading) {
                        artwork(width: geo.size.width, height: geo.size.height)

                        if let url = item.teaserHLSURL {
                            TeaserSurface(url: url, enabled: isActive)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        }

                        LinearGradient(
                            colors: [.black.opacity(0.45), .clear,
                                     OTNetTheme.background.opacity(0.6), OTNetTheme.background],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(width: geo.size.width, height: geo.size.height)

                        textBlock
                            .padding(.horizontal, 20)
                            .padding(.bottom, 96)
                            .frame(width: geo.size.width, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)

                actionButtons
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .frame(width: geo.size.width, alignment: .leading)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }

    private func artwork(width: CGFloat, height: CGFloat) -> some View {
        AsyncImage(url: item.landscapeURL ?? item.posterURL) { phase in
            switch phase {
            case .success(let img):
                img.resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height, alignment: .top)
                    .clipped()
            default:
                Rectangle().fill(OTNetTheme.card)
                    .frame(width: width, height: height)
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let url = item.titleImageURL {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFit()
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
                    .lineLimit(2)
            }
            ContentMetaStrip(item: item)
            if let description = item.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(OTNetTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            PlayButton(size: .compact, action: onPlay)

            if canUseList {
                MyListButton(
                    isInList: myList.contains(item.id),
                    isPending: myList.isPending(item.id),
                    size: .compact
                ) {
                    Task {
                        let idx = auth.activeProfileIndex
                        if myList.contains(item.id) {
                            await myList.remove(item.id, profileIndex: idx)
                        } else {
                            await myList.add(item, profileIndex: idx)
                        }
                    }
                }
            }

            if let rating = item.ageRating, !rating.isEmpty {
                AgeRatingBadge(rating: rating)
            }
        }
    }
}
