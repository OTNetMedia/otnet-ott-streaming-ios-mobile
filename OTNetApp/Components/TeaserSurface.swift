import AVFoundation
import AVKit
import SwiftUI
import UIKit

/// Plays a muted, looped HLS teaser behind hero artwork. Cross-fades in once
/// the first frame is actually rendered so we never see a black flash.
struct TeaserSurface: View {
    let url: URL
    var enabled: Bool = true
    @StateObject private var controller = TeaserController()

    var body: some View {
        ZStack {
            TeaserVideoSurface(player: controller.player)
                .opacity(controller.hasVideo ? 1 : 0)
                .animation(.easeInOut(duration: 0.6), value: controller.hasVideo)
        }
        .allowsHitTesting(false)
        .onAppear { controller.start(url: url, enabled: enabled) }
        .onDisappear { controller.stop() }
        .onChange(of: enabled) { newValue in
            if newValue { controller.start(url: url, enabled: true) } else { controller.pause() }
        }
        .onChange(of: url) { newURL in
            controller.start(url: newURL, enabled: enabled)
        }
    }
}

@MainActor
private final class TeaserController: ObservableObject {
    let player = AVPlayer()
    @Published var hasVideo = false

    private var loopObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    private var currentURL: URL?

    init() {
        player.isMuted = true
        player.actionAtItemEnd = .none
    }

    func start(url: URL, enabled: Bool) {
        guard enabled else { pause(); return }
        if url != currentURL {
            currentURL = url
            hasVideo = false
            let asset = AVURLAsset(url: url)
            let item = AVPlayerItem(asset: asset)
            attachLoop(item: item)
            statusObservation?.invalidate()
            statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                Task { @MainActor in
                    guard let self else { return }
                    if item.status == .readyToPlay { self.player.play() }
                }
            }
            rateObservation?.invalidate()
            rateObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] p, _ in
                Task { @MainActor in
                    self?.hasVideo = (p.timeControlStatus == .playing)
                }
            }
            player.replaceCurrentItem(with: item)
        }
        player.play()
    }

    func pause() {
        player.pause()
    }

    func stop() {
        player.pause()
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        statusObservation?.invalidate(); statusObservation = nil
        rateObservation?.invalidate(); rateObservation = nil
        player.replaceCurrentItem(with: nil)
        currentURL = nil
        hasVideo = false
    }

    private func attachLoop(item: AVPlayerItem) {
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.player.seek(to: .zero)
            self?.player.play()
        }
    }
}

private struct TeaserVideoSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> View {
        let v = View()
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resizeAspectFill
        v.backgroundColor = .black
        return v
    }

    func updateUIView(_ uiView: View, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    final class View: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
