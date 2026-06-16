import AVKit
import SwiftUI
import UIKit

struct PlayerView: UIViewControllerRepresentable {
    let content: Content
    var contextDescription: String? = nil

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.allowsPictureInPicturePlayback = true
        vc.entersFullScreenWhenPlaybackBegins = true
        vc.modalPresentationStyle = .fullScreen
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        Task { await configure(vc) }
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}

    @MainActor
    private func configure(_ vc: AVPlayerViewController) async {
        do {
            let mint = try await OTNetAPI.shared.mintPlayback(contentId: content.id, protocolName: "hls")

            guard let url = URL(string: mint.playback.masterUrl) else {
                throw APIError.invalidURL
            }

            if let fairplay = mint.playback.drm?.fairplay,
               let certURL = URL(string: fairplay.certificateUrl) {
                guard var components = URLComponents(string: "https://otnet.io/api/v1/playback/drm/license") else {
                    throw APIError.invalidURL
                }
                components.queryItems = [
                    URLQueryItem(name: "token",  value: mint.playback.sessionToken),
                    URLQueryItem(name: "system", value: "fairplay"),
                ]
                guard let licenseURL = components.url else {
                    throw APIError.invalidURL
                }

                let keySession = AVContentKeySession(keySystem: .fairPlayStreaming)
                let delegate = FairPlayKeyDelegate(
                    licenseURL: licenseURL,
                    certificateURL: certURL,
                    onError: { err in
                        Task {
                            await reportError(code: "drm-license-failure",
                                              category: "drm",
                                              message: err.localizedDescription,
                                              severity: "critical")
                        }
                    }
                )
                keySession.setDelegate(delegate, queue: .main)

                let asset = AVURLAsset(url: url)
                keySession.addContentKeyRecipient(asset)
                vc.player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
                objc_setAssociatedObject(vc, AssocKeys.keySession, keySession, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                objc_setAssociatedObject(vc, AssocKeys.delegate,  delegate,   .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            } else {
                vc.player = AVPlayer(url: url)
            }
            vc.player?.play()
        } catch {
            await reportError(code: "mint-failure",
                              category: "playback",
                              message: error.localizedDescription,
                              severity: "critical")
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

private final class AssocKeyToken {}
private enum AssocKeys {
    static let keySession = Unmanaged.passUnretained(AssocKeyToken()).toOpaque()
    static let delegate   = Unmanaged.passUnretained(AssocKeyToken()).toOpaque()
}
