import AVFoundation
import SwiftUI

struct AppLaunchView: View {
    @State private var player: AVPlayer?
    @State private var playbackObserver: NSObjectProtocol?
    @State private var isReady = false
    @State private var splashOpacity = 1.0
    @State private var hasStarted = false

    var body: some View {
        ZStack {
            // RootView is present beneath the splash from the first in-app frame so
            // the final dissolve cannot reveal a default SwiftUI background.
            RootView()
                .opacity(isReady ? 1 : 0)

            if !isReady || splashOpacity > 0 {
                splashLayer
                    .opacity(splashOpacity)
                    .zIndex(1)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            prepareAndPlayIntro()
        }
        .onDisappear {
            releasePlayer()
        }
    }

    private var splashLayer: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let player {
                SplashVideoView(player: player)
                    .ignoresSafeArea()
            }
        }
        .accessibilityHidden(true)
    }

    private func prepareAndPlayIntro() {
        guard let url = Bundle.main.url(forResource: "IrfaaliBrandIntro", withExtension: "mp4") else {
            // A missing bundle resource should never strand the user on launch.
            completeIntro(animated: false)
            return
        }

        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 1

        let localPlayer = AVPlayer(playerItem: item)
        localPlayer.actionAtItemEnd = .pause
        localPlayer.isMuted = true
        localPlayer.automaticallyWaitsToMinimizeStalling = false
        player = localPlayer

        playbackObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            Task { @MainActor in
                completeIntro(animated: true)
            }
        }

        localPlayer.preroll(atRate: 1) { ready in
            DispatchQueue.main.async {
                if ready {
                    localPlayer.playImmediately(atRate: 1)
                } else {
                    localPlayer.play()
                }
            }
        }
    }

    @MainActor
    private func completeIntro(animated: Bool) {
        guard !isReady else { return }

        isReady = true

        if animated {
            withAnimation(.easeInOut(duration: 0.18)) {
                splashOpacity = 0
            }

            Task {
                try? await Task.sleep(for: .milliseconds(190))
                releasePlayer()
            }
        } else {
            splashOpacity = 0
            releasePlayer()
        }
    }

    @MainActor
    private func releasePlayer() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil

        if let playbackObserver {
            NotificationCenter.default.removeObserver(playbackObserver)
            self.playbackObserver = nil
        }
    }
}
