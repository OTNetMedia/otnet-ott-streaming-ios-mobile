import SwiftUI

struct ContentDetailView: View {
    let content: Content
    @State private var showingPlayer = false
    @State private var showingPaywall = false
    @StateObject private var vm = ContentDetailViewModel()
    @EnvironmentObject private var myList: MyListStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var settingsStore: SettingsStore

    private var displayed: Content { vm.detail ?? content }
    private var isPaywalled: Bool { displayed.entitled == false && displayed.paywall != nil }
    private var viewerAuthRequired: Bool { !(settingsStore.settings?.viewerAuthNone ?? false) }
    private var canUseList: Bool { viewerAuthRequired && auth.isSignedIn }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    heroSection(width: geo.size.width)
                        .ignoresSafeArea(edges: .top)
                    titleSection
                    ContentMetaStrip(item: displayed, includeContentType: true)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    playButton

                    if let synopsis = displayed.description, !synopsis.isEmpty {
                        Text(synopsis)
                            .font(.body)
                            .foregroundStyle(OTNetTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !advisories.isEmpty {
                        advisoriesSection
                    }

                    if !castMembers.isEmpty {
                        castSection
                    }

                    if !infoRows.isEmpty {
                        infoSection
                    }

                    if displayed.isSeries {
                        SeasonsView(seriesId: content.id)
                            .padding(.top, 12)
                    }
                }
                .frame(width: geo.size.width, alignment: .leading)
                .padding(.bottom, 60)
            }
        }
        .background(OTNetTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.black.opacity(0.55), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
            }
            .padding(.leading, 16)
            .padding(.top, 8)
        }
        .fullScreenCover(isPresented: $showingPlayer) {
            PlayerView(content: displayed)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            PaywallSurface(
                content: displayed,
                info: displayed.paywall,
                onDismiss: { showingPaywall = false },
                onPurchaseConfirmed: {
                    showingPaywall = false
                    Task {
                        await vm.load(content.id)
                        await MainActor.run { showingPlayer = true }
                    }
                }
            )
        }
        .navigationDestination(for: Content.self) { ContentDetailView(content: $0) }
        .navigationDestination(for: CastAndCrewRoute.self) { _ in
            CastAndCrewView(content: displayed)
        }
        .navigationDestination(for: Personnel.self) { person in
            PersonDetailView(personnel: person)
        }
        .task { await vm.load(content.id) }
    }

    private func heroSection(width: CGFloat) -> some View {
        let height: CGFloat = 360
        return ZStack {
            CachedAsyncImage(url: displayed.backdropURL ?? displayed.landscapeURL ?? displayed.posterURL) { phase in
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

            if let teaserURL = displayed.teaserHLSURL {
                TeaserSurface(url: teaserURL)
                    .frame(width: width, height: height)
                    .clipped()
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [.black.opacity(0.55), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 90)
        }
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, OTNetTheme.background],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 160)
        }
    }

    private var titleSection: some View {
        Group {
            if let url = displayed.titleImageURL {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFit()
                    } else {
                        Text(displayed.displayTitle)
                            .font(.largeTitle).bold()
                            .foregroundStyle(OTNetTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxHeight: 120)
            } else {
                Text(displayed.displayTitle)
                    .font(.largeTitle).bold()
                    .foregroundStyle(OTNetTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private var playButton: some View {
        HStack(spacing: 12) {
            if isPaywalled {
                PaywallCTAButton(paywall: displayed.paywall) {
                    showingPaywall = true
                }
            } else {
                PlayButton { showingPlayer = true }
            }

            if canUseList {
                MyListButton(
                    isInList: myList.contains(displayed.id),
                    isPending: myList.isPending(displayed.id)
                ) {
                    Task { await toggleMyList() }
                }
            }

            if let rating = displayed.ageRating, !rating.isEmpty {
                AgeRatingBadge(rating: rating)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggleMyList() async {
        let idx = auth.activeProfileIndex
        if myList.contains(displayed.id) {
            await myList.remove(displayed.id, profileIndex: idx)
        } else {
            await myList.add(displayed, profileIndex: idx)
        }
    }

    private var castMembers: [Personnel] {
        (displayed.personnel ?? []).filter { $0.displayName != nil }
    }

    private var castSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink(value: CastAndCrewRoute(contentId: content.id)) {
                HStack(spacing: 6) {
                    Text("Cast & Crew")
                        .font(.headline)
                        .foregroundStyle(OTNetTheme.textPrimary)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(OTNetTheme.textSecondary)
                    Spacer()
                    Text("See all")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(OTNetTheme.primary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(castMembers, id: \.id) { member in
                        NavigationLink(value: member) {
                            CastRowCard(member: member)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var advisories: [String] {
        (displayed.contentAdvisory ?? []).filter { !$0.isEmpty }
    }

    private var advisoriesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Advisory")
                .font(.headline)
                .foregroundStyle(OTNetTheme.textPrimary)
            FlowHStack(items: advisories)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct InfoRow: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    private var infoRows: [InfoRow] {
        var rows: [InfoRow] = []
        if let group = displayed.primaryGroup?.name, !group.isEmpty {
            rows.append(.init(label: "Studio", value: group))
        }
        if let group = displayed.secondaryGroup?.name, !group.isEmpty {
            rows.append(.init(label: "Distributor", value: group))
        }
        if let org = displayed.organization?.name, !org.isEmpty {
            rows.append(.init(label: "Network", value: org))
        }
        if let venue = displayed.venue, !venue.isEmpty {
            rows.append(.init(label: "Venue", value: venue))
        }
        if let lang = displayed.firstMedia?.language, !lang.isEmpty {
            rows.append(.init(label: "Language", value: lang.uppercased()))
        }
        for item in displayed.metadata ?? [] {
            guard
                let key = item.key, !key.isEmpty,
                let value = item.value, !value.isEmpty,
                key.caseInsensitiveCompare("Rating") != .orderedSame
            else { continue }
            rows.append(.init(label: key, value: value))
        }
        return rows
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.headline)
                .foregroundStyle(OTNetTheme.textPrimary)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(infoRows) { row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.label)
                            .font(.subheadline)
                            .foregroundStyle(OTNetTheme.textSecondary)
                            .frame(width: 110, alignment: .leading)
                        Text(row.value)
                            .font(.subheadline)
                            .foregroundStyle(OTNetTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CastAndCrewRoute: Hashable {
    let contentId: String
}

private struct CastRowCard: View {
    let member: Personnel

    var body: some View {
        VStack(spacing: 6) {
            AsyncImage(url: member.headshotURL) { phase in
                switch phase {
                case .success(let img):
                    img.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 64, height: 64, alignment: .top)
                        .clipped()
                default:
                    ZStack {
                        Circle().fill(OTNetTheme.card)
                        Image(systemName: "person.fill")
                            .foregroundStyle(OTNetTheme.textSecondary)
                    }
                    .frame(width: 64, height: 64)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(Circle())

            Text(member.displayName ?? "")
                .font(.caption.weight(.semibold))
                .foregroundStyle(OTNetTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            if let role = member.role {
                Text(role)
                    .font(.caption2)
                    .foregroundStyle(OTNetTheme.textSecondary)
            }
        }
        .frame(width: 80)
    }
}

private struct FlowHStack: View {
    let items: [String]
    var body: some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption)
                    .foregroundStyle(OTNetTheme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(OTNetTheme.muted, in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

@MainActor
final class ContentDetailViewModel: ObservableObject {
    @Published var detail: Content?

    func load(_ id: String) async {
        do {
            detail = try await OTNetAPI.shared.content(id: id)
        } catch {
            DebugProbe.log("content detail load failed: \(error)")
        }
    }
}
