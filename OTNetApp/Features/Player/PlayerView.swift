import AVKit
import SwiftUI
import UIKit

struct PlayerView: View {
    enum Mode { case vod, live }
    let content: Content
    var mode: Mode = .vod

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var state: PlayerState = .loading
    @State private var keyDelegate: FairPlayKeyDelegate?
    @State private var keySession: AVContentKeySession?

    enum PlayerState {
        case loading
        case ready(AVPlayer, MintResponse.Playback)
        case error(String)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch state {
            case .loading:
                VStack(spacing: 12) {
                    ProgressView().tint(.white).scaleEffect(1.3)
                    Text("Preparing playback…")
                        .foregroundStyle(.white.opacity(0.7))
                        .font(.footnote)
                }
            case .ready(let player, let playback):
                CustomPlayerSurface(
                    player: player,
                    title: content.displayTitle,
                    subtitle: mode == .live ? "Live" : content.primaryGenreName,
                    isLive: mode == .live,
                    bifURL: playback.resources?.bifURL,
                    adBreaks: playback.adbreaks?.breaks ?? [],
                    blockAdSkipping: (playback.adbreaks?.blockSkipping ?? false)
                        || (settingsStore.settings?.blockAdSkipping ?? false),
                    onDismiss: { dismiss() }
                )
            case .error(let message):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(message)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("Close") { dismiss() }
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(.white, in: Capsule())
                }
            }
        }
        .task(id: content.id) { await load() }
    }

    private func load() async {
        DebugProbe.log("PlayerView.load() starting for contentId=\(content.id)")
        do {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try? AVAudioSession.sharedInstance().setActive(true)

            let mint: MintResponse
            switch mode {
            case .vod:
                mint = try await OTNetAPI.shared.mintPlayback(contentId: content.id, protocolName: "hls")
            case .live:
                mint = try await OTNetAPI.shared.mintLive(channelId: content.id, protocolName: "hls")
            }
            guard let url = URL(string: mint.playback.masterUrl) else {
                throw APIError.invalidURL
            }
            DebugProbe.log("masterUrl=\(url.absoluteString)")

            let player: AVPlayer
            if let fairplay = mint.playback.drm?.fairplay,
               let certURL = URL(string: fairplay.certificateUrl) {
                guard var components = URLComponents(string: "https://otnet.io/api/v1/playback/drm/license") else {
                    throw APIError.invalidURL
                }
                guard let token = mint.playback.effectiveToken else {
                    throw APIError.invalidURL
                }
                components.queryItems = [
                    URLQueryItem(name: "token",  value: token),
                    URLQueryItem(name: "system", value: "fairplay"),
                ]
                guard let licenseURL = components.url else {
                    throw APIError.invalidURL
                }
                DebugProbe.log("FairPlay licenseURL=\(licenseURL.absoluteString.prefix(120))…")
                DebugProbe.log("FairPlay certURL=\(certURL.absoluteString)")

                let delegate = FairPlayKeyDelegate(
                    licenseURL: licenseURL,
                    certificateURL: certURL,
                    onError: { err in
                        Task { @MainActor in
                            DebugProbe.log("FairPlay onError: \(err.localizedDescription)")
                            await reportError(code: "drm-license-failure",
                                              category: "drm",
                                              message: err.localizedDescription,
                                              severity: "critical")
                            state = .error("DRM failed: \(err.localizedDescription)")
                        }
                    }
                )
                let session = AVContentKeySession(keySystem: .fairPlayStreaming)
                session.setDelegate(delegate, queue: .main)

                let asset = AVURLAsset(url: url)
                session.addContentKeyRecipient(asset)

                self.keyDelegate = delegate
                self.keySession = session

                player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
            } else {
                DebugProbe.log("No FairPlay block on mint response — playing as clear HLS")
                player = AVPlayer(url: url)
            }

            await MainActor.run {
                state = .ready(player, mint.playback)
                player.play()
                DebugProbe.log("AVPlayer.play() called")
            }
        } catch {
            DebugProbe.log("PlayerView.load() failed: \(error.localizedDescription)")
            await reportError(code: "mint-failure",
                              category: "playback",
                              message: error.localizedDescription,
                              severity: "critical")
            await MainActor.run {
                state = .error(error.localizedDescription)
            }
        }
    }

    private func reportError(code: String, category: String, message: String, severity: String) async {
        let report = PlayerErrorReport(
            errorCode: code,
            errorCategory: category,
            message: message,
            severity: severity,
            device: UIDevice.current.name,
            deviceType: "ios",
            contentId: content.id
        )
        await OTNetAPI.shared.reportPlayerError(report)
    }
}

