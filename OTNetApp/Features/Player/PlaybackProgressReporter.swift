import AVFoundation
import Foundation

/// Periodically POSTs playback progress to `/telemetry/progress` via the
/// authenticated OTNetAPI path (X-Api-Key + viewer Bearer + contentId in
/// body) so writes route into `WatchProgress` for this viewer's profile,
/// matching what the GET reads back.
@MainActor
final class PlaybackProgressReporter {
    private let contentId: String?
    private let channelId: String?
    private let profileIndex: Int
    private weak var player: AVPlayer?

    private var timer: Timer?
    private var lastSentAt: Date = .distantPast
    private let interval: TimeInterval = 15

    init(contentId: String?,
         channelId: String?,
         profileIndex: Int,
         player: AVPlayer) {
        self.contentId = contentId
        self.channelId = channelId
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

        let cid = contentId
        let chid = channelId
        let pIdx = profileIndex
        let device = Self.deviceId
        Task {
            do {
                try await OTNetAPI.shared.postWatchProgress(
                    contentId: cid,
                    channelId: chid,
                    profileIndex: pIdx,
                    progressSeconds: progress,
                    durationSeconds: duration,
                    deviceId: device
                )
                DebugProbe.log("progress POST ok progress=\(progress) duration=\(duration)")
            } catch {
                DebugProbe.log("progress POST failed: \(error.localizedDescription)")
            }
        }
    }

    /// Stable per-install identifier, mirroring the web player's
    /// `localStorage["otnet:deviceId"]` convention.
    private static let deviceId: String = {
        let key = "otnet:deviceId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }()
}
