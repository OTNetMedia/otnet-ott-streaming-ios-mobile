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
                LiveTVContent(
                    channels: channels,
                    now: vm.now,
                    onPlay: { info in nowPlaying = info }
                )
            }
        }
        .background(OTNetTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
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
                portrait: nil, landscape: nil, backdrop: nil,
                childCount: nil, sortOrder: nil, parent: nil, genres: nil,
                entitled: true, paywall: nil, monetization: nil,
                date: nil, primaryGroup: nil, secondaryGroup: nil,
                organization: nil, metadata: nil, personnel: nil,
                contentAdvisory: nil, venue: nil, teaser: nil
            )
            PlayerView(content: stub, mode: .live).ignoresSafeArea()
        }
    }
}

private struct LiveTVContent: View {
    let channels: [EPGChannel]
    let now: Date
    let onPlay: (EPGChannelInfo) -> Void

    @State private var jumpTarget: TimeJumpTarget = .now
    @State private var zoomLevel: Int = 2 // index into zoomLevels
    @State private var selectedChannelId: String?
    private let zoomLevels: [CGFloat] = [10, 16, 22, 32, 48, 72]

    private var featured: (EPGChannelInfo, EPGProgram)? {
        // If the user has tapped a channel rail, prefer that channel's
        // currently-airing program over the auto-pick.
        if let selectedChannelId,
           let selectedChannel = channels.first(where: { $0.channel?.id == selectedChannelId }),
           let info = selectedChannel.channel,
           let p = currentlyAiring(in: selectedChannel) {
            return (info, p)
        }

        // Auto-pick: first channel with a currently-airing program that has
        // a thumbnail; fall back to any currently-airing program.
        var fallback: (EPGChannelInfo, EPGProgram)?
        for ch in channels {
            guard let info = ch.channel else { continue }
            for p in ch.programs ?? [] {
                guard let s = p.startDate, let e = p.endDate,
                      s <= now, e > now else { continue }
                if p.thumbnailURL != nil { return (info, p) }
                if fallback == nil { fallback = (info, p) }
            }
        }
        return fallback
    }

    private func currentlyAiring(in channel: EPGChannel) -> EPGProgram? {
        for p in channel.programs ?? [] {
            if let s = p.startDate, let e = p.endDate, s <= now, e > now {
                return p
            }
        }
        return nil
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if let (channel, program) = featured {
                        LiveHeroCard(
                            channel: channel,
                            program: program,
                            now: now,
                            onPlay: { onPlay(channel) }
                        )
                        .frame(width: geo.size.width)
                    }

                    HStack(spacing: 10) {
                        TimeJumpStrip(selected: $jumpTarget)
                        ZoomControls(
                            canZoomOut: zoomLevel > 0,
                            canZoomIn: zoomLevel < zoomLevels.count - 1,
                            onZoomOut: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    zoomLevel = max(0, zoomLevel - 1)
                                }
                            },
                            onZoomIn: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    zoomLevel = min(zoomLevels.count - 1, zoomLevel + 1)
                                }
                            }
                        )
                    }
                    .frame(width: geo.size.width - 32)
                    .padding(.horizontal, 16)

                    EPGGrid(
                        channels: channels,
                        now: now,
                        pxPerMin: zoomLevels[zoomLevel],
                        jumpTarget: jumpTarget,
                        selectedChannelId: selectedChannelId,
                        onSelectChannel: { id in
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            // Immediate update — animation delay was hiding
                            // the perceived swap. The hero's image swap is
                            // already cross-faded by the AsyncImage transition.
                            selectedChannelId = id
                        },
                        onPlay: onPlay
                    )
                    .frame(width: geo.size.width, alignment: .leading)
                }
                .frame(width: geo.size.width, alignment: .leading)
                .padding(.bottom, 40)
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}

// MARK: - Live Hero Card

private struct LiveHeroCard: View {
    let channel: EPGChannelInfo
    let program: EPGProgram
    let now: Date
    let onPlay: () -> Void

    private var remainingText: String {
        guard let end = program.endDate else { return "" }
        let remaining = max(0, end.timeIntervalSince(now))
        let mins = Int(remaining / 60)
        if mins >= 60 {
            let h = mins / 60, m = mins % 60
            return m == 0 ? "\(h)h left" : "\(h)h \(m)m left"
        }
        return "\(max(1, mins))m left"
    }

    private var progress: CGFloat {
        guard let s = program.startDate, let e = program.endDate else { return 0 }
        let total = e.timeIntervalSince(s)
        guard total > 0 else { return 0 }
        return CGFloat(max(0, min(1, now.timeIntervalSince(s) / total)))
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .frame(height: 320)
            .background(
                backdrop.overlay(
                    LinearGradient(
                        colors: [.black.opacity(0.55), .clear, .black.opacity(0.4), .black.opacity(0.9)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            )
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { onPlay() }
    }

    @ViewBuilder private var backdrop: some View {
        let url = program.thumbnailURL ?? channel.backdropURL
        CachedAsyncImage(url: url) { phase in
            switch phase {
            case .success(let img):
                img.resizable().aspectRatio(contentMode: .fill)
            default:
                ZStack {
                    LinearGradient(
                        colors: [OTNetTheme.card, OTNetTheme.muted],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Image(systemName: "tv")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.15))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .clipped()
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(.red).frame(width: 8, height: 8)
                    .shadow(color: .red.opacity(0.8), radius: 4)
                Text("LIVE NOW")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(.white)
                if let num = channel.channelNumber {
                    Text("· CH \(num)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                if let chName = channel.name, !chName.isEmpty {
                    Text("· \(chName)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
            }

            Text(program.displayTitle)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .shadow(color: .black.opacity(0.6), radius: 4)

            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill").font(.system(size: 13, weight: .bold))
                    Text("Watch Live").font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(.white, in: Capsule())

                if !remainingText.isEmpty {
                    Text(remainingText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(.top, 2)

            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18)).frame(height: 3)
                Capsule().fill(Color.red).frame(width: max(3, 280 * progress), height: 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
    }
}

// MARK: - Time jump strip

enum TimeJumpTarget: Int, Hashable, CaseIterable {
    case now, plus1h, plus3h, plus6h, plus12h

    var label: String {
        switch self {
        case .now: return "Now"
        case .plus1h: return "+1h"
        case .plus3h: return "+3h"
        case .plus6h: return "+6h"
        case .plus12h: return "+12h"
        }
    }

    var icon: String? { self == .now ? "dot.radiowaves.left.and.right" : nil }

    var offsetSeconds: TimeInterval {
        switch self {
        case .now: return 0
        case .plus1h: return 3600
        case .plus3h: return 3 * 3600
        case .plus6h: return 6 * 3600
        case .plus12h: return 12 * 3600
        }
    }
}

private struct TimeJumpStrip: View {
    @Binding var selected: TimeJumpTarget

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TimeJumpTarget.allCases, id: \.rawValue) { target in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selected = target
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if let icon = target.icon {
                                Image(systemName: icon)
                                    .font(.system(size: 11, weight: .bold))
                            }
                            Text(target.label)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(selected == target ? .white : OTNetTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(
                                selected == target
                                    ? OTNetTheme.primary
                                    : Color.white.opacity(0.06)
                            )
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                selected == target
                                    ? Color.clear
                                    : OTNetTheme.border,
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Zoom controls

private struct ZoomControls: View {
    let canZoomOut: Bool
    let canZoomIn: Bool
    let onZoomOut: () -> Void
    let onZoomIn: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onZoomOut) {
                Image(systemName: "minus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(canZoomOut ? OTNetTheme.textPrimary : OTNetTheme.textTertiary)
                    .frame(width: 36, height: 30)
            }
            .buttonStyle(.plain)
            .disabled(!canZoomOut)

            Rectangle().fill(OTNetTheme.border).frame(width: 1, height: 16)

            Button(action: onZoomIn) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(canZoomIn ? OTNetTheme.textPrimary : OTNetTheme.textTertiary)
                    .frame(width: 36, height: 30)
            }
            .buttonStyle(.plain)
            .disabled(!canZoomIn)
        }
        .background(
            Capsule().fill(Color.white.opacity(0.06))
        )
        .overlay(
            Capsule().strokeBorder(OTNetTheme.border, lineWidth: 1)
        )
    }
}

// MARK: - EPG Grid

private struct EPGGrid: View {
    let channels: [EPGChannel]
    let now: Date
    let pxPerMin: CGFloat
    let jumpTarget: TimeJumpTarget
    let selectedChannelId: String?
    let onSelectChannel: (String?) -> Void
    let onPlay: (EPGChannelInfo) -> Void

    private let slotMin: Int = 30
    private let pastHours: Int = 1
    private let maxTimelineWidth: CGFloat = 11000
    /// Dynamic visible window: shrinks as the user zooms in so the
    /// underlying CALayer never blows past renderable limits.
    private var futureHours: Int {
        let perHour = pxPerMin * 60
        let safe = Int(floor(maxTimelineWidth / perHour)) - pastHours
        return max(2, min(12, safe))
    }
    private let railWidth: CGFloat = 74
    private let rowHeight: CGFloat = 92
    private let headerHeight: CGFloat = 44
    private let tileMinWidth: CGFloat = 8
    private let tileGap: CGFloat = 3
    private let logoSize: CGFloat = 64

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
    private func anchorId(for target: TimeJumpTarget) -> String {
        "jump-\(target.rawValue)"
    }

    private let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    var body: some View {
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
                    .overlay(nowLine, alignment: .topLeading)
                    .background(alignment: .topLeading) {
                        // Single moving anchor — repositions when jumpTarget
                        // changes. Massively lighter than 5 fixed HStacks.
                        HStack(spacing: 0) {
                            Color.clear.frame(
                                width: xPosition(forOffsetFromNow: jumpTarget.offsetSeconds),
                                height: 1
                            )
                            Color.clear.frame(width: 1, height: 1).id("jump-anchor")
                        }
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            proxy.scrollTo("jump-anchor", anchor: .center)
                        }
                    }
                }
                .onChange(of: jumpTarget) { newValue in
                    withAnimation(.easeInOut(duration: 0.45)) {
                        proxy.scrollTo("jump-anchor",
                                       anchor: newValue == .now ? .center : .leading)
                    }
                }
                .onChange(of: pxPerMin) { _ in
                    // Re-anchor on zoom so the focused time (now, +1h, etc.)
                    // stays in view instead of drifting off as the timeline
                    // expands or contracts.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("jump-anchor",
                                           anchor: jumpTarget == .now ? .center : .leading)
                        }
                    }
                }
            }
        }
    }

    private func xPosition(forOffsetFromNow offsetSeconds: TimeInterval) -> CGFloat {
        let target = now.timeIntervalSince1970 + offsetSeconds
        let clamped = max(startMs, min(endMs, target))
        return CGFloat((clamped - startMs) / 60) * pxPerMin
    }

    private var channelRail: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: headerHeight)
            ForEach(channels) { ch in
                Button {
                    onSelectChannel(ch.channel?.id)
                } label: {
                    railCell(channel: ch, isSelected: ch.channel?.id == selectedChannelId)
                }
                .buttonStyle(.plain)
                Divider().background(OTNetTheme.border.opacity(0.4))
            }
        }
        .frame(width: railWidth)
        .background(OTNetTheme.background)
    }

    private func railCell(channel: EPGChannel, isSelected: Bool) -> some View {
        // Logo top-aligned with the same 6pt offset the program tiles use,
        // so the rail and timeline rows visually line up edge-to-edge.
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isSelected ? OTNetTheme.primary : .white.opacity(0.08),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
            CachedAsyncImage(url: channel.channel?.logoURL) { phase in
                if case .success(let img) = phase {
                    img.resizable().aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "tv")
                        .font(.system(size: 20))
                        .foregroundStyle(OTNetTheme.textTertiary)
                }
            }
            .padding(7)

            if let num = channel.channel?.channelNumber {
                Text("\(num)")
                    .font(.system(size: 9, weight: .heavy).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(
                            isSelected ? OTNetTheme.primary : Color.black.opacity(0.75)
                        )
                    )
                    .overlay(
                        Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                    )
                    .offset(x: -2, y: -2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: logoSize, height: logoSize)
        .padding(.top, 6) // match the 6pt top offset of the program tiles
        .frame(width: railWidth, height: rowHeight, alignment: .top)
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
                // Single tile centred on the now-line for empty channels.
                let tileWidth: CGFloat = 280
                Button {
                    if let info = channel.channel { onPlay(info) }
                } label: {
                    ProgramTile(
                        title: channel.channel?.name ?? "Live",
                        subtitle: "LIVE LOOP · 24/7",
                        isLive: true,
                        progress: 0,
                        width: tileWidth,
                        thumbnailURL: nil
                    )
                }
                .buttonStyle(.plain)
                .offset(x: max(0, nowOffset - tileWidth / 2), y: 6)
            } else {
                ForEach(programs, id: \.id) { p in
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
            let natural = CGFloat((ce - cs) / 60) * pxPerMin - tileGap
            let width = max(tileMinWidth, natural)
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
                    width: width,
                    thumbnailURL: program.thumbnailURL
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
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.red)
                .frame(width: 2,
                       height: CGFloat(channels.count) * (rowHeight + 1) + headerHeight)
                .offset(x: nowOffset)

            Text(timeFmt.string(from: now))
                .font(.system(size: 12, weight: .heavy).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                .fixedSize()
                .offset(x: nowOffset - 26, y: 6)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Program Tile

private struct ProgramTile: View {
    let title: String
    let subtitle: String?
    let isLive: Bool
    let progress: CGFloat
    let width: CGFloat
    var thumbnailURL: URL? = nil

    private var showTitle: Bool { width >= 52 }
    private var showSubtitle: Bool { width >= 130 }
    private var titleLines: Int { width >= 110 ? 2 : 1 }
    private var horizontalPadding: CGFloat { width >= 60 ? 8 : 4 }
    private var showThumbnail: Bool { thumbnailURL != nil && width >= 100 }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            background
            if showThumbnail {
                LinearGradient(
                    colors: [.black.opacity(0.0), .black.opacity(0.75)],
                    startPoint: .top, endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 2) {
                if showTitle {
                    Text(title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(titleLines)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .shadow(color: .black.opacity(showThumbnail ? 0.7 : 0), radius: 3)
                }
                if showSubtitle, let subtitle {
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .shadow(color: .black.opacity(showThumbnail ? 0.7 : 0), radius: 3)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 6)
            .frame(width: width, alignment: .leading)

            if isLive && progress > 0 {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.red)
                    .frame(width: width * progress, height: 2)
            }
        }
        .frame(width: width, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isLive ? OTNetTheme.primary.opacity(0.5) : OTNetTheme.border,
                              lineWidth: isLive ? 1 : 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder private var background: some View {
        if showThumbnail, let url = thumbnailURL {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle().fill(
                        isLive ? OTNetTheme.card : OTNetTheme.muted.opacity(0.7)
                    )
                }
            }
        } else {
            Rectangle().fill(
                isLive ? OTNetTheme.card : OTNetTheme.muted.opacity(0.7)
            )
        }
    }
}

// MARK: - View Model

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
            prefetchHeroThumbnails(for: merged)
        } catch {
            phase = .failed(error)
        }
    }

    /// Warm the image cache with every channel's currently-airing thumbnail
    /// plus its backdrop, so tapping a rail cell swaps the hero instantly
    /// instead of waiting on a cold network fetch.
    private func prefetchHeroThumbnails(for channels: [EPGChannel]) {
        let now = Date()
        var urls: [URL?] = []
        for ch in channels {
            urls.append(ch.channel?.backdropURL)
            urls.append(ch.channel?.logoURL)
            for p in ch.programs ?? [] {
                if let s = p.startDate, let e = p.endDate,
                   s <= now, e > now {
                    urls.append(p.thumbnailURL)
                    break
                }
            }
        }
        ImageCache.shared.prefetch(urls)
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
                // 60s tick — the now-line moves visibly only every minute
                // anyway, and tile progress (which derives from now) only
                // shifts a few % per minute too.
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                await MainActor.run { self?.now = Date() }
            }
        }
    }
}
