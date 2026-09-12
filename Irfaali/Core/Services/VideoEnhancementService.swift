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
        let videoComposition = AVVideoComposition(
            asset: asset,
            applyingCIFiltersWithHandler: { request in
                autoreleasepool {
                    let sourceExtent = request.sourceImage.extent
                    var image = request.sourceImage.clampedToExtent()

                    if normalized.denoise > 0.001 {
                        image = image.applyingFilter(
                            "CINoiseReduction",
                            parameters: [
                                "inputNoiseLevel": 0.006 + normalized.denoise * 0.055,
                                "inputSharpness": 0.34 + normalized.detailRecovery * 0.24
                            ]
                        )
                    }

                    if normalized.detailRecovery > 0.001 {
                        image = image.applyingFilter(
                            "CIUnsharpMask",
                            parameters: [
                                "inputRadius": 1.25 + normalized.detailRecovery * 2.75,
                                "inputIntensity": 0.08 + normalized.detailRecovery * 0.72
                            ]
                        )
                    }

                    if normalized.sharpening > 0.001 {
                        image = image.applyingFilter(
                            "CISharpenLuminance",
                            parameters: [
                                "inputSharpness": 0.05 + normalized.sharpening * 0.82
                            ]
                        )
                    }

                    if normalized.colorBoost > 0.001 {
                        image = image.applyingFilter(
                            "CIColorControls",
                            parameters: [
                                "inputSaturation": 1.0 + normalized.colorBoost * 0.18,
                                "inputContrast": 1.0 + normalized.colorBoost * 0.07,
                                "inputBrightness": normalized.colorBoost * 0.008
                            ]
                        )
                    }

                    request.finish(with: image.cropped(to: sourceExtent), context: nil)
                }
            }
        )

        let preset = preferHEVC ? AVAssetExportPresetHEVCHighestQuality : AVAssetExportPresetHighestQuality
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw EnhancementError.cannotCreateSession
        }

        let destination = try uniqueDestination()
        guard session.supportedFileTypes.contains(.mp4) else {
            throw EnhancementError.unsupportedOutputType
        }

        session.outputURL = destination
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        session.videoComposition = videoComposition

        let monitor = Task {
            while !Task.isCancelled {
                progress(Double(session.progress))
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }

        defer { monitor.cancel() }

        do {
            try await withTaskCancellationHandler(operation: {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    session.exportAsynchronously {
                        switch session.status {
                        case .completed:
                            progress(1)
                            continuation.resume()
                        case .failed:
                            continuation.resume(throwing: EnhancementError.failed(session.error?.localizedDescription ?? "Unknown error"))
                        case .cancelled:
                            continuation.resume(throwing: CancellationError())
                        default:
                            continuation.resume(throwing: EnhancementError.failed("Unexpected export state: \(session.status.rawValue)"))
                        }
                    }
                }
            }, onCancel: {
                session.cancelExport()
            })
            try Task.checkCancellation()
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }

        return destination
    }

    private func uniqueDestination() throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = documents.appendingPathComponent("Irfaali Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("irfaali-enhanced-\(UUID().uuidString).mp4")
    }
}
