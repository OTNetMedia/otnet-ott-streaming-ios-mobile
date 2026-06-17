import AVFoundation
import AVKit
import SwiftUI
import UIKit

struct CustomPlayerSurface: View {
    @StateObject private var controller: PlayerController
    let title: String
    let subtitle: String?
    let isLive: Bool
    let bifURL: URL?
    let adBreaks: [AdBreak]
    let blockAdSkipping: Bool
    let onDismiss: () -> Void

    init(player: AVPlayer,
         title: String,
         subtitle: String? = nil,
         isLive: Bool,
         bifURL: URL? = nil,
         adBreaks: [AdBreak] = [],
         blockAdSkipping: Bool = false,
         onDismiss: @escaping () -> Void) {
        _controller = StateObject(wrappedValue: PlayerController(player: player))
        self.title = title
        self.subtitle = subtitle
        self.isLive = isLive
        self.bifURL = bifURL
        self.adBreaks = adBreaks
        self.blockAdSkipping = blockAdSkipping
        self.onDismiss = onDismiss
    }

    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?
    @State private var dragValue: Double?
    @State private var isScrubbing = false
    @State private var bif: BIFFile?
    @State private var thumbX: CGFloat = 0
    @State private var scrubThumb: UIImage?
    @State private var blockedToast: BlockedToast?
    @State private var toastTask: Task<Void, Never>?

    private struct BlockedToast: Equatable {
        let id = UUID()
        let message: String
    }

    private var currentAd: AdBreak? {
        let t = controller.currentTime
        return adBreaks.first { ad in
            guard let s = ad.startTime, let e = ad.endTime else { return false }
            return t >= s && t < e
        }
    }

    private var seekEnabled: Bool {
        // Live: scrubbing disabled. VOD: while an ad is on and we're blocking
        // skip, forward seeks are disallowed (but rewind is always fine).
        !isLive
    }

    /// Given an arbitrary target seek time, returns the time we should
    /// actually seek to, plus the ad that blocked the jump (if any).
    private func clampedTarget(currentTime: Double, target: Double) -> (Double, AdBreak?) {
        guard blockAdSkipping, target > currentTime else { return (target, nil) }
        // Find the first ad whose start lies inside the requested forward jump
        // and that the user has not already played through.
        let furthest = controller.furthestWatchedTime
        let blocking = adBreaks
            .filter { ad in
                guard let s = ad.startTime, let e = ad.endTime else { return false }
                if ad.skippable == true { return false }
                if e <= furthest { return false }            // already watched
                return s > currentTime && s < target
            }
            .min(by: { ($0.startTime ?? .infinity) < ($1.startTime ?? .infinity) })
        if let blocking, let s = blocking.startTime {
            return (s, blocking)
        }
        // Also: if currently inside an ad we haven't completed, clamp forward
        // seeks to the ad's end (i.e. don't let user skip the rest of it).
        if let ad = currentAd, let e = ad.endTime, target > e, ad.skippable != true {
            return (currentTime, ad)
        }
        return (target, nil)
    }

    private func showBlockedToast(_ message: String = "Can't skip ads") {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            blockedToast = BlockedToast(message: message)
        }
        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                blockedToast = nil
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VideoSurface(player: controller.player)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { toggleControls() }

            if controlsVisible {
                LinearGradient(
                    colors: [.black.opacity(0.85), .black.opacity(0.1), .clear,
                             .black.opacity(0.1), .black.opacity(0.95)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            if controller.isBuffering {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.6)
                    .shadow(color: .black.opacity(0.5), radius: 8)
            }

            if controlsVisible {
                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 0)
                    centerControls
                    Spacer(minLength: 0)
                    bottomBar
                }
                .transition(.opacity)
            }

            if let ad = currentAd {
                AdBadge(ad: ad,
                        currentTime: controller.currentTime,
                        skipBlocked: forwardSkipBlocked)
                    .padding(.top, 16)
                    .padding(.trailing, 22)
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: .topTrailing)
                    .allowsHitTesting(false)
            }

            if let toast = blockedToast {
                BlockedToastView(message: toast.message)
                    .padding(.top, 70)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .id(toast.id)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .lockOrientation(to: [.landscapeLeft, .landscapeRight], rotateTo: .landscapeRight)
        .onAppear {
            scheduleAutoHide()
            Task { @MainActor in
                if let url = bifURL { bif = await BIFLoader.shared.load(url) }
            }
        }
        .onDisappear {
            hideTask?.cancel()
            controller.tearDown()
        }
        .onReceive(controller.$isPlaying) { _ in scheduleAutoHide() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 14) {
            iconButton(systemName: "xmark", size: 18, action: onDismiss)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.6), radius: 4)
                if let subtitle, !subtitle.isEmpty, !isLive {
                    Text(subtitle.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.65))
                }
            }

            Spacer(minLength: 8)

            if isLive { liveBadge }

            iconButton(systemName: "captions.bubble", size: 17) {
                // placeholder — opens audio/subtitles in future
            }
            .opacity(0.65)
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
    }

    private var liveBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .shadow(color: .red.opacity(0.8), radius: 4)
            Text("LIVE")
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial.opacity(0.6), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
    }

    private func iconButton(systemName: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial.opacity(0.5), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.1), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 6)
        }
    }

    // MARK: - Center controls

    private var forwardSkipBlocked: Bool {
        guard blockAdSkipping, let ad = currentAd else { return false }
        return ad.skippable != true
    }

    private var centerControls: some View {
        HStack(spacing: 64) {
            seekButton(systemName: "gobackward.10", disabled: isLive) { skip(by: -10) }

            Button { controller.togglePlay() } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial.opacity(0.45))
                        .frame(width: 84, height: 84)
                        .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
                    Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 38, weight: .black))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 8)
                        .offset(x: controller.isPlaying ? 0 : 2)
                }
            }
            .buttonStyle(PressableButtonStyle())

            seekButton(systemName: "goforward.10",
                       disabled: isLive || forwardSkipBlocked) {
                if forwardSkipBlocked {
                    showBlockedToast()
                } else {
                    skip(by: 10)
                }
            }
        }
    }

    private func seekButton(systemName: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 8)
                .frame(width: 64, height: 64)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.25 : 1)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if isLive {
                HStack(spacing: 10) {
                    Capsule().fill(.red).frame(height: 4)
                    Text("STREAMING LIVE")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.85))
                }
            } else {
                ScrubBar(
                    value: dragValue ?? controller.currentTime,
                    range: 0...max(controller.duration, 1),
                    adBreaks: adBreaks,
                    isScrubbing: $isScrubbing,
                    onChange: { v, x in
                        dragValue = v
                        thumbX = x
                        if let bif {
                            let img = bif.image(at: v)
                            if img !== scrubThumb { scrubThumb = img }
                        }
                        hideTask?.cancel()
                    },
                    onCommit: { v in
                        let (target, blocker) = clampedTarget(currentTime: controller.currentTime, target: v)
                        controller.seek(to: target)
                        if blocker != nil {
                            showBlockedToast()
                        }
                        dragValue = nil
                        scrubThumb = nil
                        scheduleAutoHide()
                    }
                )
                .overlay(alignment: .bottomLeading) {
                    if isScrubbing, let img = scrubThumb {
                        ScrubThumbnail(image: img,
                                       time: format(dragValue ?? controller.currentTime))
                            .offset(x: thumbX - 70, y: -16)
                            .transition(.opacity)
                    }
                }

                HStack {
                    Text(format(dragValue ?? controller.currentTime))
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                    Spacer()
                    Text("-" + format(max(0, controller.duration - (dragValue ?? controller.currentTime))))
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Helpers

    private func skip(by seconds: Double) {
        let now = controller.currentTime
        let target = max(0, now + seconds)
        // Backwards skips are always allowed.
        if seconds < 0 {
            controller.seek(to: target)
        } else {
            let (clamped, blocker) = clampedTarget(currentTime: now, target: target)
            controller.seek(to: clamped)
            if blocker != nil { showBlockedToast() }
        }
        scheduleAutoHide()
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.22)) {
            controlsVisible.toggle()
        }
        if controlsVisible { scheduleAutoHide() }
    }

    private func scheduleAutoHide() {
        hideTask?.cancel()
        guard controller.isPlaying, !isScrubbing else { return }
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled, controller.isPlaying, !isScrubbing else { return }
            withAnimation(.easeInOut(duration: 0.28)) {
                controlsVisible = false
            }
        }
    }

    private func format(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}

// MARK: - Custom scrubber

private struct ScrubBar: View {
    let value: Double
    let range: ClosedRange<Double>
    let adBreaks: [AdBreak]
    @Binding var isScrubbing: Bool
    let onChange: (Double, CGFloat) -> Void
    let onCommit: (Double) -> Void

    @State private var localOverride: Double?

    private var progress: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        let displayed = localOverride ?? value
        return CGFloat((displayed - range.lowerBound) / span)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let height: CGFloat = isScrubbing ? 6 : 4
            let thumb: CGFloat = isScrubbing ? 16 : 12
            let span = range.upperBound - range.lowerBound

            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.22))
                    .frame(height: height)
                Capsule().fill(OTNetTheme.primary)
                    .frame(width: max(thumb / 2, w * progress), height: height)

                // Ad-break range markers (orange segments along the bar)
                ForEach(adBreaks) { ad in
                    if let s = ad.startTime, let d = ad.duration, span > 0 {
                        let left = CGFloat((s - range.lowerBound) / span) * w
                        let width = max(3, CGFloat(d / span) * w)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.orange)
                            .frame(width: width, height: height + 2)
                            .offset(x: left)
                    }
                }

                Circle()
                    .fill(.white)
                    .frame(width: thumb, height: thumb)
                    .shadow(color: .black.opacity(0.4), radius: 4)
                    .offset(x: max(0, w * progress - thumb / 2))
            }
            .frame(height: 22)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let x = min(max(0, g.location.x), w)
                        let newValue = range.lowerBound + Double(x / w) * span
                        if !isScrubbing {
                            withAnimation(.easeOut(duration: 0.15)) { isScrubbing = true }
                        }
                        localOverride = newValue
                        onChange(newValue, x)
                    }
                    .onEnded { _ in
                        if let v = localOverride { onCommit(v) }
                        localOverride = nil
                        withAnimation(.easeOut(duration: 0.2)) { isScrubbing = false }
                    }
            )
            .animation(.easeInOut(duration: 0.15), value: isScrubbing)
        }
        .frame(height: 22)
    }
}

private struct ScrubThumbnail: View {
    let image: UIImage
    let time: String

    var body: some View {
        VStack(spacing: 4) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 140, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
            Text(time)
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.black.opacity(0.7), in: Capsule())
        }
        .frame(width: 140)
    }
}

private struct AdBadge: View {
    let ad: AdBreak
    let currentTime: Double
    let skipBlocked: Bool

    private var remaining: Int {
        guard let end = ad.endTime else { return 0 }
        return max(0, Int((end - currentTime).rounded(.up)))
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                if skipBlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white)
                }
                Text("AD")
                    .font(.system(size: 11, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.orange, in: RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 1) {
                if let title = ad.adTitle ?? ad.name, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Text(skipBlocked ? "Can't skip · \(remaining)s left" : "Ends in \(remaining)s")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
    }
}

private struct BlockedToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .bold))
            Text(message)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial.opacity(0.75), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 12, y: 4)
    }
}

// MARK: - Player Controller

@MainActor
final class PlayerController: ObservableObject {
    let player: AVPlayer
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isBuffering: Bool = true
    /// Highest playhead position the user has actually played through.
    /// Used to decide whether an ad block has been "watched".
    @Published var furthestWatchedTime: Double = 0

    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?

    init(player: AVPlayer) {
        self.player = player
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let t = time.seconds.isFinite ? time.seconds : 0
            self.currentTime = t
            self.furthestWatchedTime = max(self.furthestWatchedTime, t)
            if let item = self.player.currentItem {
                let d = item.duration.seconds
                self.duration = d.isFinite ? max(0, d) : 0
            }
        }
        statusObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] p, _ in
            Task { @MainActor in
                guard let self else { return }
                self.isPlaying = p.timeControlStatus == .playing
                self.isBuffering = p.timeControlStatus == .waitingToPlayAtSpecifiedRate
            }
        }
    }

    func tearDown() {
        if let t = timeObserver { player.removeTimeObserver(t); timeObserver = nil }
        statusObservation?.invalidate(); statusObservation = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    func togglePlay() {
        if player.timeControlStatus == .playing { player.pause() } else { player.play() }
    }

    func skip(by seconds: Double) {
        let target = max(0, currentTime + seconds)
        seek(to: target)
    }

    func seek(to seconds: Double) {
        let cm = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: cm, toleranceBefore: .zero, toleranceAfter: .zero)
    }
}

// MARK: - Video Surface (AVPlayerLayer)

struct VideoSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> VideoSurfaceView {
        let view = VideoSurfaceView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: VideoSurfaceView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
}

final class VideoSurfaceView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
