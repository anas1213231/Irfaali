import AVFoundation
import SwiftUI
import UIKit

struct SplashVideoView: View {
    let onFinished: () -> Void

    @StateObject private var controller = SplashVideoController()

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            SplashPlayerSurface(player: controller.player)
                .ignoresSafeArea()
        }
        .background(Color.black)
        .onAppear {
            controller.play(onFinished: onFinished)
        }
        .onDisappear {
            controller.cleanup()
        }
        .accessibilityHidden(true)
    }
}

@MainActor
private final class SplashVideoController: ObservableObject {
    @Published private(set) var player: AVPlayer?

    private var completionObserver: NSObjectProtocol?
    private var didStart = false
    private var didFinish = false
    private var onFinished: (() -> Void)?

    func play(onFinished: @escaping () -> Void) {
        guard !didStart else { return }
        didStart = true
        self.onFinished = onFinished

        guard let url = Bundle.main.url(forResource: "IrfaaliSplash", withExtension: "mp4") else {
            assertionFailure("IrfaaliSplash.mp4 is missing from the app bundle")
            return
        }

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .pause
        player.automaticallyWaitsToMinimizeStalling = false
        self.player = player

        completionObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.finishPlayback()
            }
        }

        player.play()
    }

    func cleanup() {
        if let completionObserver {
            NotificationCenter.default.removeObserver(completionObserver)
            self.completionObserver = nil
        }

        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        onFinished = nil
    }

    private func finishPlayback() {
        guard !didFinish else { return }
        didFinish = true
        let completion = onFinished
        cleanup()
        completion?()
    }
}

private struct SplashPlayerSurface: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> SplashPlayerUIView {
        let view = SplashPlayerUIView()
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: SplashPlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class SplashPlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        playerLayer.backgroundColor = UIColor.black.cgColor
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
        playerLayer.backgroundColor = UIColor.black.cgColor
        playerLayer.videoGravity = .resizeAspect
    }
}
