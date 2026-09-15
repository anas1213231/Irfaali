@preconcurrency import AVFoundation
import CoreImage
import Foundation

final class VideoEnhancementService {
    enum EnhancementError: LocalizedError {
        case cannotCreateSession
        case unsupportedOutputType
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .cannotCreateSession:
                return "تعذر تشغيل محرك تحسين الصورة لهذا الفيديو."
            case .unsupportedOutputType:
                return "صيغة الإخراج غير مدعومة في مرحلة تحسين الصورة."
            case .failed(let message):
                return "تعثر تحسين الصورة: \(message)"
            }
        }
    }

    func enhance(
        sourceURL: URL,
        settings: VideoEnhancementSettings,
        preferHEVC: Bool,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        try Task.checkCancellation()

        let normalized = settings.normalized()
        guard normalized.isEnabled else {
            progress(1)
            return sourceURL
        }

        let asset = AVURLAsset(url: sourceURL)
        let videoComposition = VideoImageFilters.composition(asset: asset, settings: normalized).mutableCopy() as! AVMutableVideoComposition

        let info = try await VideoAnalyzer().analyze(url: sourceURL)
        videoComposition.frameDuration = CMTime(seconds: 1 / max(info.sourceFPS, 1), preferredTimescale: 60_000)
        let destination = try uniqueDestination()
        try await VideoEncodingService.encode(
            asset: asset, composition: videoComposition,
            size: CGSize(width: info.width, height: info.height), fps: info.sourceFPS,
            hevc: preferHEVC, bitrate: info.estimatedBitrate,
            destination: destination, progress: progress
        )

        return destination
    }

    private func uniqueDestination() throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = documents.appendingPathComponent("Irfaali Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("irfaali-enhanced-\(UUID().uuidString).mp4")
    }
}
