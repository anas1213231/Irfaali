import AVFoundation
import SwiftUI

struct SplashVideoView: View {
    let onFinished: () -> Void

    @State private var player: AVPlayer?
    @State private var playbackObserver: NSObjectProtocol?
    @State private var didFinish = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                SplashPlayerSurface(player: player)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }
        }
        .onAppear(perform: prepareAndPlay)
        .onDisappear(perform: tearDown)
    }

    private func prepareAndPlay() {
        guard player == nil, let url = Bundle.main.url(forResource: "IrfaaliBrandIntro", withExtension: "mp4") else {
            finishOnce()
            return
        }

        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 0

        let player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .pause
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = true
        self.player = player

        playbackObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            finishOnce()
        }

        player.playImmediately(atRate: 1)
    }

    private func finishOnce() {
        guard !didFinish else { return }
        didFinish = true
        player?.pause()
        onFinished()
    }

    private func tearDown() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil

        if let playbackObserver {
            NotificationCenter.default.removeObserver(playbackObserver)
            self.playbackObserver = nil
        }
    }
}

private struct SplashPlayerSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> SplashPlayerView {
        let view = SplashPlayerView()
        view.backgroundColor = .black
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: SplashPlayerView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = .resizeAspect
    }
}

private final class SplashPlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
