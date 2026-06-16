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
        let variants = content.media?.first?.variants ?? []
        let chosen = variants.first(where: { $0.protocolName == "hls" }) ?? variants.first
        guard let variant = chosen,
              let entry = variant.entrypoint,
              let url = URL(string: entry) else {
            await reportError(code: "no-variant",
                              category: "playback",
                              message: "No playable variant found.",
                              severity: "high")
            return
        }

        if variant.drm?.fairplay != nil {
            do {
                let (license, cert) = try await resolveFairPlayUrls(
                    variant: variant, contentId: content.id, mediaIndex: 0
                )
                let keySession = AVContentKeySession(keySystem: .fairPlayStreaming)
                let delegate = FairPlayKeyDelegate(
                    licenseURL: license,
                    certificateURL: cert,
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
            } catch {
                await reportError(code: "drm-session-failure",
                                  category: "drm",
                                  message: error.localizedDescription,
                                  severity: "critical")
                return
            }
        } else {
            vc.player = AVPlayer(url: url)
        }
        vc.player?.play()
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
