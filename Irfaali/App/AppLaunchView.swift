import AVFoundation
import Combine
import SwiftUI
import UIKit

struct AppLaunchView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var splashPlayback = SplashPlaybackController()
    @State private var didStartSplash = false
    @State private var hasCompletedSplash = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            RootView()
                .opacity(hasCompletedSplash ? 1 : 0)
                .allowsHitTesting(hasCompletedSplash)

            if !hasCompletedSplash {
                SplashVideoView(player: splashPlayback.player)
                    .transition(.opacity)
                    .onReceive(
                        NotificationCenter.default
                            .publisher(for: .AVPlayerItemDidPlayToEndTime)
                            .receive(on: RunLoop.main)
                    ) { notification in
                        guard
                            let expectedItem = splashPlayback.item,
                            let endedItem = notification.object as? AVPlayerItem,
                            endedItem === expectedItem
                        else {
                            return
                        }

                        completeSplash()
                    }
            }
        }
        .background(Color.black)
        .onAppear {
            startSplashIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard didStartSplash, !hasCompletedSplash else { return }

            switch newPhase {
            case .active:
                splashPlayback.resume()
            case .inactive, .background:
                splashPlayback.pause()
            @unknown default:
                break
            }
        }
    }

    private func startSplashIfNeeded() {
        guard !didStartSplash else { return }
        didStartSplash = true

        guard splashPlayback.isPrepared else {
            hasCompletedSplash = true
            return
        }

        splashPlayback.playFromBeginning()
    }

    private func completeSplash() {
        guard !hasCompletedSplash else { return }

        withAnimation(
            .easeInOut(duration: 0.18),
            completionCriteria: .logicallyComplete
        ) {
            hasCompletedSplash = true
        } completion: {
            splashPlayback.releaseResources()
        }
    }
}

private struct SplashVideoView: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> SplashPlayerView {
        let view = SplashPlayerView()
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: SplashPlayerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class SplashPlayerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        let launchBlack = UIColor(red: 0.004, green: 0.007, blue: 0.014, alpha: 1)
        backgroundColor = launchBlack
        isUserInteractionEnabled = false
        playerLayer.backgroundColor = launchBlack.cgColor
        playerLayer.videoGravity = .resizeAspect
    }
}

@MainActor
private final class SplashPlaybackController: ObservableObject {
    private(set) var player: AVPlayer?
    private(set) var item: AVPlayerItem?

    var isPrepared: Bool {
        player != nil && item != nil
    }

    init(bundle: Bundle = .main) {
        guard let url = Self.splashURL(in: bundle) else { return }

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.volume = 0
        player.actionAtItemEnd = .pause
        player.automaticallyWaitsToMinimizeStalling = false

        self.item = item
        self.player = player
    }

    func playFromBeginning() {
        guard let player else { return }
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        player.playImmediately(atRate: 1)
    }

    func resume() {
        guard let player, player.timeControlStatus != .playing else { return }
        player.playImmediately(atRate: 1)
    }

    func pause() {
        player?.pause()
    }

    func releaseResources() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        item = nil
    }

    private static func splashURL(in bundle: Bundle) -> URL? {
        bundle.url(forResource: "IrfaaliSplash", withExtension: "mp4")
            ?? bundle.url(
                forResource: "IrfaaliSplash",
                withExtension: "mp4",
                subdirectory: "Media"
            )
    }
}
