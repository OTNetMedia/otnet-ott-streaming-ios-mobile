import SwiftUI

struct LiveTVView: View {
    @StateObject private var vm = LiveTVViewModel()
    @State private var nowPlaying: EPGChannelInfo?

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
                EPGGrid(channels: channels, now: vm.now) { info in
                    nowPlaying = info
                }
            }
        }
        .background(OTNetTheme.background.ignoresSafeArea())
        .navigationTitle("Live TV")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .fullScreenCover(item: $nowPlaying) { info in
            let stub = Content(
                id: info.id ?? "",
                title: info.name,
                description: info.description,
                contentType: "live",
                type: "live",
                media: nil, ageRating: nil, titleImage: nil,
                childCount: nil, sortOrder: nil, parent: nil, genres: nil,
                entitled: true, paywall: nil, monetization: nil,
                date: nil, primaryGroup: nil, secondaryGroup: nil,
                organization: nil, metadata: nil, personnel: nil,
                contentAdvisory: nil, venue: nil
            )
            PlayerView(content: stub, mode: .live).ignoresSafeArea()
        }
    }
}

private struct EPGGrid: View {
    let channels: [EPGChannel]
    let now: Date
    let onPlay: (EPGChannelInfo) -> Void

    private let pxPerMin: CGFloat = 5
    private let slotMin: Int = 30
    private let pastHours: Int = 1
    private let futureHours: Int = 12
    private let railWidth: CGFloat = 96
    private let rowHeight: CGFloat = 84
    private let headerHeight: CGFloat = 32

    private var startMs: TimeInterval {
        let mins = floor(now.timeIntervalSince1970 / 60.0)
        let snapped = mins - mins.truncatingRemainder(dividingBy: Double(slotMin))
        return snapped * 60 - Double(pastHours) * 3600
    }
    private var endMs: TimeInterval { startMs + Double(pastHours + futureHours) * 3600 }
    private var timelineWidth: CGFloat {
        CGFloat((endMs - startMs) / 60) * pxPerMin
    }
    private var nowOffset: CGFloat {
        CGFloat((now.timeIntervalSince1970 - startMs) / 60) * pxPerMin
    }
    private var slots: [TimeInterval] {
        stride(from: startMs, to: endMs, by: Double(slotMin) * 60).map { $0 }
    }

    private let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    channelRail
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            VStack(spacing: 0) {
                                timeHeader
                                ForEach(channels) { ch in
                                    timelineRow(for: ch)
                                    Divider().background(OTNetTheme.border.opacity(0.4))
                                }
                            }
                            .background(
                                nowLine
                                    .id("now"),
                                alignment: .topLeading
                            )
                        }
                        .onAppear {
                            withAnimation { proxy.scrollTo("now", anchor: .leading) }
                        }
                    }
                }
            }
        }
    }

    private var channelRail: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: headerHeight)
            ForEach(channels) { ch in
                Button {
                    if let info = ch.channel { onPlay(info) }
                } label: {
                    railCell(channel: ch)
                }
                .buttonStyle(.plain)
                Divider().background(OTNetTheme.border.opacity(0.4))
            }
        }
        .frame(width: railWidth)
        .background(OTNetTheme.background)
    }

    private func railCell(channel: EPGChannel) -> some View {
        HStack(spacing: 8) {
            AsyncImage(url: channel.channel?.logoURL) { phase in
                if case .success(let img) = phase {
                    img.resizable().aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "tv")
                        .foregroundStyle(OTNetTheme.textTertiary)
                }
            }
            .frame(width: 40, height: 40)
            .padding(4)
            .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                if let num = channel.channel?.channelNumber {
                    Text("CH \(num)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(OTNetTheme.textTertiary)
                }
                Text(channel.channel?.name ?? "Channel")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(OTNetTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(width: railWidth, height: rowHeight, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var timeHeader: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(OTNetTheme.background)
                .frame(width: timelineWidth, height: headerHeight)
            ForEach(Array(slots.enumerated()), id: \.offset) { idx, slot in
                let left = CGFloat((slot - startMs) / 60) * pxPerMin
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(OTNetTheme.textSecondary.opacity(0.3))
                        .frame(width: 1, height: 10)
                    Text(idx == 0 ? "ON NOW" : timeFmt.string(from: Date(timeIntervalSince1970: slot)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(OTNetTheme.textSecondary)
                }
                .offset(x: left, y: 10)
            }
        }
        .frame(width: timelineWidth, height: headerHeight, alignment: .topLeading)
    }

    private func timelineRow(for channel: EPGChannel) -> some View {
        let programs = channel.programs ?? []
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(Color.clear)
                .frame(width: timelineWidth, height: rowHeight)
            if programs.isEmpty {
                Button {
                    if let info = channel.channel { onPlay(info) }
                } label: {
                    ProgramTile(
                        title: channel.channel?.name ?? "Live",
                        subtitle: "LIVE LOOP · 24/7",
                        isLive: true,
                        progress: 0,
                        width: max(180, timelineWidth - 8)
                    )
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: 6)
            } else {
                ForEach(Array(programs.enumerated()), id: \.offset) { _, p in
                    tile(channel: channel, program: p)
                }
            }
        }
        .frame(width: timelineWidth, height: rowHeight, alignment: .topLeading)
    }

    @ViewBuilder
    private func tile(channel: EPGChannel, program: EPGProgram) -> some View {
        if let pStart = program.startDate?.timeIntervalSince1970,
           let pEnd = program.endDate?.timeIntervalSince1970,
           pEnd > startMs, pStart < endMs {
            let cs = max(pStart, startMs)
            let ce = min(pEnd, endMs)
            let left = CGFloat((cs - startMs) / 60) * pxPerMin
            let width = max(60, CGFloat((ce - cs) / 60) * pxPerMin - 3)
            let isLive = pStart <= now.timeIntervalSince1970 && pEnd > now.timeIntervalSince1970
            let progress = isLive ? CGFloat((now.timeIntervalSince1970 - pStart) / (pEnd - pStart)) : 0
            let subtitle = subtitle(for: program)

            Button {
                if let info = channel.channel { onPlay(info) }
            } label: {
                ProgramTile(
                    title: program.displayTitle,
                    subtitle: subtitle,
                    isLive: isLive,
                    progress: progress,
                    width: width
                )
            }
            .buttonStyle(.plain)
            .offset(x: left, y: 6)
        }
    }

    private func subtitle(for program: EPGProgram) -> String? {
        guard let s = program.startDate, let e = program.endDate else { return nil }
        return "\(timeFmt.string(from: s)) – \(timeFmt.string(from: e))"
    }

    private var nowLine: some View {
        Rectangle()
            .fill(Color.red)
            .frame(width: 2,
                   height: CGFloat(channels.count) * (rowHeight + 1) + headerHeight)
            .offset(x: nowOffset)
            .overlay(alignment: .top) {
                Text(timeFmt.string(from: now))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.red, in: Capsule())
                    .offset(x: nowOffset - 18, y: -2)
            }
            .allowsHitTesting(false)
    }
}

private struct ProgramTile: View {
    let title: String
    let subtitle: String?
    let isLive: Bool
    let progress: CGFloat
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(isLive ? OTNetTheme.card : OTNetTheme.muted.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isLive ? OTNetTheme.primary.opacity(0.5) : OTNetTheme.border,
                                      lineWidth: isLive ? 1 : 0.5)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(OTNetTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if width > 110, let subtitle {
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(OTNetTheme.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(width: width, alignment: .leading)

            if isLive && progress > 0 {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.red)
                    .frame(width: width * progress, height: 2)
            }
        }
        .frame(width: width, height: 64)
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

@MainActor
final class LiveTVViewModel: ObservableObject {
    @Published var phase: Phase<[EPGChannel]> = .loading
    @Published var now: Date = Date()
    private var tickTask: Task<Void, Never>?

    deinit { tickTask?.cancel() }

    func load() async {
        phase = .loading
        do {
            let merged = try await loadMergedChannels()
            phase = merged.isEmpty ? .empty : .loaded(merged)
            startTicker()
        } catch {
            phase = .failed(error)
        }
    }

    private func loadMergedChannels() async throws -> [EPGChannel] {
        let infos: [EPGChannelInfo]
        do {
            let resp = try await OTNetAPI.shared.channels()
            infos = resp.channels ?? []
        } catch {
            let fallback = try await OTNetAPI.shared.epg(back: 1, ahead: 12)
            return (fallback.channels ?? []).sorted {
                ($0.channel?.channelNumber ?? .max) < ($1.channel?.channelNumber ?? .max)
            }
        }

        let merged: [EPGChannel] = await withTaskGroup(of: EPGChannel.self) { group in
            for info in infos {
                group.addTask {
                    guard let id = info.id else {
                        return EPGChannel(channel: info, playbackUrl: nil, programs: [])
                    }
                    do {
                        let res = try await OTNetAPI.shared.epg(channelId: id, back: 1, ahead: 12)
                        let progs = res.channels?.first?.programs ?? []
                        return EPGChannel(channel: info, playbackUrl: res.channels?.first?.playbackUrl, programs: progs)
                    } catch {
                        DebugProbe.log("epg fetch failed for \(id): \(error)")
                        return EPGChannel(channel: info, playbackUrl: nil, programs: [])
                    }
                }
            }
            var out: [EPGChannel] = []
            for await ch in group { out.append(ch) }
            return out
        }

        return merged.sorted {
            ($0.channel?.channelNumber ?? .max) < ($1.channel?.channelNumber ?? .max)
        }
    }

    private func startTicker() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                await MainActor.run { self?.now = Date() }
            }
        }
    }
}
