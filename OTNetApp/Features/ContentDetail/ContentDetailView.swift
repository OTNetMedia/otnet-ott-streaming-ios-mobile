import SwiftUI

struct ContentDetailView: View {
    let content: Content
    @State private var showingPlayer = false
    @StateObject private var vm = ContentDetailViewModel()

    private var displayed: Content { vm.detail ?? content }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    heroSection(width: geo.size.width)
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showingPlayer) {
            PlayerView(content: displayed)
                .ignoresSafeArea()
        }
        .navigationDestination(for: Content.self) { ContentDetailView(content: $0) }
        .navigationDestination(for: CastAndCrewRoute.self) { _ in
            CastAndCrewView(content: displayed)
        }
        .task { await vm.load(content.id) }
    }

    private func heroSection(width: CGFloat) -> some View {
        AsyncImage(url: displayed.landscapeURL ?? displayed.posterURL) { phase in
            switch phase {
            case .success(let img):
                img.resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: 280, alignment: .top)
                    .clipped()
            default:
                Rectangle().fill(OTNetTheme.card)
                    .frame(width: width, height: 280)
            }
        }
        .frame(width: width, height: 280)
        .clipped()
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, OTNetTheme.background],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 120)
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
        HStack(spacing: 8) {
            Button {
                showingPlayer = true
            } label: {
                Label("Play", systemImage: "play.fill")
                    .bold()
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(OTNetTheme.primary)

            if let rating = displayed.ageRating, !rating.isEmpty {
                AgeRatingBadge(rating: rating)
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                        VStack(spacing: 6) {
                            AsyncImage(url: member.headshotURL) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFill()
                                default:
                                    Circle().fill(OTNetTheme.card)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .foregroundStyle(OTNetTheme.textSecondary)
                                        )
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
