import AVFoundation
import Foundation

/// Periodically POSTs playback progress to `/telemetry/progress` using the
/// playback session's `analyticsToken` as the Bearer. The token carries
/// viewerId + contentId so the server can attribute the write to
/// `WatchProgress`. Using the viewer access JWT here routes writes into a
/// separate anonymous collection that the viewer GET never reads.
@MainActor
final class PlaybackProgressReporter {
    private let analyticsToken: String
    private let profileIndex: Int
    private weak var player: AVPlayer?

    private var timer: Timer?
    private var lastSentAt: Date = .distantPast
    private let interval: TimeInterval = 15

    init(analyticsToken: String,
         profileIndex: Int,
         player: AVPlayer) {
        self.analyticsToken = analyticsToken
        self.profileIndex = profileIndex
        self.player = player
    }

    func start() {
        send()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.send() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        send()
    }

    private func send() {
        guard let player, let item = player.currentItem else { return }
        let currentSeconds = player.currentTime().seconds
        let durationSeconds = item.duration.seconds
        let progress = Int((currentSeconds.isFinite ? max(0, currentSeconds) : 0).rounded(.down))
        let duration = Int((durationSeconds.isFinite ? max(0, durationSeconds) : 0).rounded(.down))
        guard progress > 0 || duration > 0 else { return }

        let now = Date()
        guard now.timeIntervalSince(lastSentAt) >= 1.0 else { return }
        lastSentAt = now

        let token = analyticsToken
        let pIdx = profileIndex
        Task {
            do {
                try await OTNetAPI.shared.postWatchProgress(
                    analyticsToken: token,
                    profileIndex: pIdx,
                    progressSeconds: progress,
                    durationSeconds: duration
                )
                DebugProbe.log("progress POST ok progress=\(progress) duration=\(duration)")
            } catch {
                DebugProbe.log("progress POST failed: \(error.localizedDescription)")
            }
        }
    }
}
