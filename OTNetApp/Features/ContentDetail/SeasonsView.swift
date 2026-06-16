import SwiftUI

struct SeasonsView: View {
    let seriesId: String
    @StateObject private var vm = SeasonsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Episodes")
                .font(.title3).bold()
                .foregroundStyle(OTNetTheme.textPrimary)
                .padding(.horizontal, 20)

            switch vm.phase {
            case .loading:
                HStack { Spacer(); ProgressView().tint(OTNetTheme.textSecondary); Spacer() }
                    .padding(20)
            case .empty:
                Text("No seasons available.")
                    .foregroundStyle(OTNetTheme.textSecondary)
                    .padding(.horizontal, 20)
            case .failed(let e):
                Text(e.localizedDescription)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 20)
            case .loaded(let seasons):
                if !seasons.isEmpty {
                    seasonTabs(seasons)
                    episodesList
                }
            }
        }
        .task { await vm.load(seriesId: seriesId) }
    }

    @ViewBuilder
    private func seasonTabs(_ seasons: [Content]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(seasons) { season in
                    Button {
                        vm.select(seasonId: season.id)
                    } label: {
                        Text(season.displayTitle)
                            .font(.subheadline.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                vm.selectedSeasonId == season.id ? OTNetTheme.primary : OTNetTheme.muted,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .foregroundStyle(OTNetTheme.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var episodesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(vm.episodes) { ep in
                NavigationLink(value: ep) {
                    EpisodeRow(episode: ep)
                }
                .buttonStyle(.plain)
            }
            if vm.episodes.isEmpty && !vm.episodesLoading {
                Text("No episodes available.")
                    .foregroundStyle(OTNetTheme.textSecondary)
                    .padding(.horizontal, 20)
            } else if vm.episodesLoading {
                HStack { Spacer(); ProgressView().tint(OTNetTheme.textSecondary); Spacer() }
                    .padding(.vertical, 20)
            }
        }
        .padding(.top, 8)
    }
}

private struct EpisodeRow: View {
    let episode: Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: episode.landscapeURL) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle().fill(OTNetTheme.card)
                        .overlay(Image(systemName: "play.rectangle").foregroundStyle(OTNetTheme.textTertiary))
                }
            }
            .frame(width: 140, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                if let order = episode.sortOrder {
                    Text("Episode \(order)")
                        .font(.caption)
                        .foregroundStyle(OTNetTheme.textTertiary)
                }
                Text(episode.displayTitle)
                    .font(.subheadline.bold())
                    .foregroundStyle(OTNetTheme.textPrimary)
                    .lineLimit(1)
                if let s = episode.description, !s.isEmpty {
                    Text(s)
                        .font(.caption)
                        .foregroundStyle(OTNetTheme.textSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }
}

@MainActor
final class SeasonsViewModel: ObservableObject {
    @Published var phase: Phase<[Content]> = .loading
    @Published var selectedSeasonId: String?
    @Published var episodes: [Content] = []
    @Published var episodesLoading = false

    func load(seriesId: String) async {
        phase = .loading
        do {
            let res = try await OTNetAPI.shared.children(id: seriesId)
            let seasons = (res.items ?? []).sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
            if seasons.isEmpty {
                phase = .empty
            } else {
                phase = .loaded(seasons)
                if let first = seasons.first {
                    select(seasonId: first.id)
                }
            }
        } catch {
            phase = .failed(error)
        }
    }

    func select(seasonId: String) {
        selectedSeasonId = seasonId
        Task { await loadEpisodes(seasonId: seasonId) }
    }

    private func loadEpisodes(seasonId: String) async {
        episodesLoading = true
        defer { episodesLoading = false }
        do {
            let res = try await OTNetAPI.shared.children(id: seasonId)
            episodes = (res.items ?? []).sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
        } catch {
            episodes = []
            DebugProbe.log("episodes load failed: \(error)")
        }
    }
}
