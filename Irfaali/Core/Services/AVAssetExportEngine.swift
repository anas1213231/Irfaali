@preconcurrency import AVFoundation
import CoreGraphics
import Foundation

/// AVFoundation-backed final export stage.
///
/// The video composition owns the requested render size and cadence, while the
/// export preset owns the delivery codec. HEVC uses Apple's highest-quality
/// HEVC preset; explicit H.264 requests continue to use the highest-quality
/// H.264 path so existing codec selection semantics remain truthful.
enum AVAssetExportEngine {
    enum EngineError: LocalizedError {
        case cannotCreateSession(String)
        case unsupportedMP4
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .cannotCreateSession(let preset):
                return "AVAssetExportSession could not create preset \(preset)."
            case .unsupportedMP4:
                return "This export session cannot write MP4 output."
            case .failed(let message):
                return "AVAssetExportSession failed: \(message)"
            }
        }
    }

    static func export(
        asset: AVAsset,
        videoComposition: AVMutableVideoComposition,
        targetSize: CGSize,
        fps: Double,
        useHEVC: Bool,
        destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let worker = Task.detached(priority: .userInitiated) {
            try await run(
                asset: asset,
                videoComposition: videoComposition,
                targetSize: targetSize,
                fps: fps,
                useHEVC: useHEVC,
                destination: destination,
                progress: progress
            )
        }

        try await withTaskCancellationHandler(
            operation: { try await worker.value },
            onCancel: { worker.cancel() }
        )
    }

    private static func run(
        asset: AVAsset,
        videoComposition: AVMutableVideoComposition,
        targetSize: CGSize,
        fps: Double,
        useHEVC: Bool,
        destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        try Task.checkCancellation()

        let safeFPS = max(1, min(fps, 240))
        videoComposition.renderSize = targetSize
        videoComposition.frameDuration = CMTime(
            seconds: 1 / safeFPS,
            preferredTimescale: 60_000
        )

        let preset = useHEVC
            ? AVAssetExportPresetHEVCHighestQuality
            : AVAssetExportPresetHighestQuality

        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw EngineError.cannotCreateSession(preset)
        }
        guard session.supportedFileTypes.contains(.mp4) else {
            throw EngineError.unsupportedMP4
        }

        try? FileManager.default.removeItem(at: destination)

        session.outputURL = destination
        session.outputFileType = .mp4
        session.videoComposition = videoComposition
        session.shouldOptimizeForNetworkUse = true
        session.canPerformMultiplePassesOverSourceMediaData = true
        session.allowsParallelizedExport = true

        progress(0)

        let progressTask = Task.detached(priority: .utility) {
            while !Task.isCancelled {
                let value = min(0.99, max(0, Double(session.progress)))
                progress(value)

                switch session.status {
                case .completed, .failed, .cancelled:
                    return
                default:
                    break
                }

                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        defer { progressTask.cancel() }

        do {
            try await withTaskCancellationHandler {
                try Task.checkCancellation()
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    session.exportAsynchronously {
                        switch session.status {
                        case .completed:
                            continuation.resume(returning: ())
                        case .cancelled:
                            continuation.resume(throwing: CancellationError())
                        case .failed:
                            continuation.resume(
                                throwing: session.error ?? EngineError.failed("Unknown export error")
                            )
                        case .unknown, .waiting, .exporting:
                            continuation.resume(
                                throwing: EngineError.failed("Export finished in state \(session.status.rawValue)")
                            )
                        @unknown default:
                            continuation.resume(
                                throwing: EngineError.failed("Export finished in an unknown state")
                            )
                        }
                    }
                }
            } onCancel: {
                session.cancelExport()
            }

            try Task.checkCancellation()
            progress(1)
        } catch {
            session.cancelExport()
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }
}
