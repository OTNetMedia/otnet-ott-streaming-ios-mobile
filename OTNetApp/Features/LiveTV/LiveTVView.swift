import SwiftUI

struct LiveTVView: View {
    @StateObject private var vm = LiveTVViewModel()

    var body: some View {
        Group {
            switch vm.phase {
            case .loading:
                StatePlaceholder(mode: .loading)
            case .empty:
                StatePlaceholder(mode: .empty("No live channels."))
            case .failed(let e):
                StatePlaceholder(
                    mode: .error(e.localizedDescription, retry: { Task { await vm.load() } })
                )
            case .loaded(let channels):
                List(channels) { ch in
                    ChannelRow(channel: ch)
                        .listRowBackground(OTNetTheme.card)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(OTNetTheme.background.ignoresSafeArea())
        .navigationTitle("Live TV")
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}

private struct ChannelRow: View {
    let channel: EPGChannel

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: channel.channel?.logo.flatMap(URL.init(string:))) { phase in
                if case .success(let img) = phase {
                    img.resizable().aspectRatio(contentMode: .fit)
                } else {
                    Rectangle().fill(OTNetTheme.muted)
                        .overlay(Image(systemName: "tv").foregroundStyle(OTNetTheme.textTertiary))
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(channel.channel?.name ?? "Channel")
                    .font(.subheadline.bold())
                    .foregroundStyle(OTNetTheme.textPrimary)
                Text(channel.programs?.first?.title ?? "—")
                    .font(.caption)
                    .foregroundStyle(OTNetTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "play.circle.fill")
                .font(.title3)
                .foregroundStyle(OTNetTheme.primary)
        }
    }
}

@MainActor
final class LiveTVViewModel: ObservableObject {
    @Published var phase: Phase<[EPGChannel]> = .loading

    func load() async {
        phase = .loading
        do {
            let res = try await OTNetAPI.shared.epg(back: 0, ahead: 2)
            let channels = res.channels ?? []
            phase = channels.isEmpty ? .empty : .loaded(channels)
        } catch {
            phase = .failed(error)
        }
    }
}
