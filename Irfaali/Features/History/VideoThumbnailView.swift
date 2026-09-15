import AVFoundation
import SwiftUI
import UIKit

@MainActor
final class VideoThumbnailStore {
    static let shared = VideoThumbnailStore()

    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 80
        cache.totalCostLimit = 48 * 1024 * 1024
    }

    func thumbnail(for url: URL) async -> UIImage? {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 720, height: 720)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.25, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.25, preferredTimescale: 600)

        do {
            let duration = try await asset.load(.duration)
            let seconds = max(0, duration.seconds)
            let targetSecond = min(max(seconds * 0.18, 0.15), 2.0)
            let targetTime = CMTime(seconds: targetSecond, preferredTimescale: 600)
            let result = try await generator.image(at: targetTime)
            let image = UIImage(cgImage: result.image)
            let cost = max(1, Int(image.size.width * image.size.height * image.scale * image.scale * 4))
            cache.setObject(image, forKey: key, cost: cost)
            return image
        } catch {
            return nil
        }
    }

    func removeThumbnail(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }
}

struct VideoThumbnailView: View {
    let url: URL
    let isAvailable: Bool

    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            fallback

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else if isLoading && isAvailable {
                ProgressView()
                    .tint(.white)
                    .controlSize(.small)
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.42)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipped()
        .task(id: url) {
            guard isAvailable else { return }
            isLoading = true
            image = await VideoThumbnailStore.shared.thumbnail(for: url)
            isLoading = false
        }
    }

    private var fallback: some View {
        LinearGradient(
            colors: [IrfaaliTheme.emerald.opacity(0.88), IrfaaliTheme.ink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: isAvailable ? "film.stack.fill" : "exclamationmark.triangle.fill")
                .font(.title3.bold())
                .foregroundStyle(isAvailable ? .white.opacity(0.65) : .orange)
        }
    }
}
