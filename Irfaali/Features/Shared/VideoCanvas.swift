import SwiftUI
import AVKit

/// Shared by the editor and library so both use the same playback/audio policy.
@MainActor
final class VideoPlaybackController: ObservableObject {
    let player = AVPlayer()
    @Published var error: Error?
    private var asset: AVURLAsset?

    func load(url: URL, enhancement: VideoEnhancementSettings) {
        player.pause()
        let asset = AVURLAsset(url: url)
        self.asset = asset
        let item = AVPlayerItem(asset: asset)
        if enhancement.isEnabled {
            item.videoComposition = VideoImageFilters.composition(asset: asset, settings: enhancement)
        }
        player.replaceCurrentItem(with: item)
        player.isMuted = false
        player.volume = 1
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playback, mode: .moviePlayback)
            try audio.setActive(true)
            error = nil
        } catch { self.error = error }
    }

    func update(_ enhancement: VideoEnhancementSettings) {
        guard let asset, let item = player.currentItem else { return }
        item.videoComposition = enhancement.isEnabled
            ? VideoImageFilters.composition(asset: asset, settings: enhancement) : nil
        // Refresh the paused frame without moving the playhead.
        if player.rate == 0 {
            player.seek(to: player.currentTime(), toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        asset = nil
    }
}

struct VideoCanvas: View {
    let url: URL
    let enhancement: VideoEnhancementSettings
    @StateObject private var playback = VideoPlaybackController()
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        ZStack(alignment: .top) {
            Color.black
            VideoPlayer(player: playback.player)
                // Playback time must progress left to right in both languages.
                .environment(\.layoutDirection, .leftToRight)
            if let error = playback.error {
                Text(AppErrorMessage.describe(error, isArabic: preferences.isArabic))
                    .font(.caption)
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .task(id: url) { playback.load(url: url, enhancement: enhancement) }
        .task(id: enhancement) {
            do { try await Task.sleep(for: .milliseconds(120)) } catch { return }
            playback.update(enhancement)
        }
        .onDisappear { playback.stop() }
    }
}
