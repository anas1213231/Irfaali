@preconcurrency import AVFoundation
import Foundation

struct ExportOutcome: Sendable {
    let url: URL
    let sourceFPS: Double
    let outputFPS: Double
    let fpsMode: FPSGenerationMode
    let codecLabel: String

    var fpsClassification: FPSClassification {
        FrameRateClassifier.classify(sourceFPS: sourceFPS, outputFPS: outputFPS, mode: fpsMode)
    }

    func validatedClassification(actualOutputFPS: Double) -> FPSClassification {
        FrameRateClassifier.classify(sourceFPS: sourceFPS, outputFPS: actualOutputFPS, mode: fpsMode)
    }
}

final class VideoExportService {
    enum ExportError: LocalizedError {
        case cannotCreateSession
        case unsupportedOutputType
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .cannotCreateSession: return "تعذر إنشاء جلسة التصدير لهذا الفيديو."
            case .unsupportedOutputType: return "صيغة الإخراج المطلوبة غير مدعومة لهذا الملف."
            case .failed(let message): return "فشل التصدير: \(message)"
            }
        }
    }

    func export(
        info: VideoAssetInfo,
        preset: OptimizationPreset,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> ExportOutcome {
        if preset.codec == .passthrough {
            let destination = try uniqueDestination(extension: info.url.pathExtension.isEmpty ? "mp4" : info.url.pathExtension)
            try FileManager.default.copyItem(at: info.url, to: destination)
            progress(1)
            return ExportOutcome(
                url: destination,
                sourceFPS: info.sourceFPS,
                outputFPS: info.sourceFPS,
                fpsMode: .preserved,
                codecLabel: info.videoCodec
            )
        }

        let asset = AVURLAsset(url: info.url)
        let exportPreset: String = preset.codec == .hevc ? AVAssetExportPresetHEVCHighestQuality : AVAssetExportPresetHighestQuality
        guard let session = AVAssetExportSession(asset: asset, presetName: exportPreset) else {
            throw ExportError.cannotCreateSession
        }

        let destination = try uniqueDestination(extension: "mp4")
        guard session.supportedFileTypes.contains(.mp4) else { throw ExportError.unsupportedOutputType }
        session.outputURL = destination
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = preset.isPlatformPreset

        let cap = preset.maximumFPS
        let needsRetiming = cap.map { info.sourceFPS > $0 + 0.01 } ?? false
        let outputFPS = needsRetiming ? (cap ?? info.sourceFPS) : info.sourceFPS

        if needsRetiming {
            let composition = AVMutableVideoComposition(propertiesOf: asset)
            composition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(outputFPS.rounded()))
            session.videoComposition = composition
        }

        let monitor = Task {
            while !Task.isCancelled {
                progress(Double(session.progress))
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }

        defer { monitor.cancel() }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                switch session.status {
                case .completed:
                    progress(1)
                    continuation.resume()
                case .failed:
                    continuation.resume(throwing: ExportError.failed(session.error?.localizedDescription ?? "Unknown error"))
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                default:
                    continuation.resume(throwing: ExportError.failed("Unexpected export state: \(session.status.rawValue)"))
                }
            }
        }

        return ExportOutcome(
            url: destination,
            sourceFPS: info.sourceFPS,
            outputFPS: outputFPS,
            fpsMode: needsRetiming ? .retimed : .preserved,
            codecLabel: preset.codec == .hevc ? "H.265 / HEVC" : "H.264 / AVC"
        )
    }

    private func uniqueDestination(extension fileExtension: String) throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = documents.appendingPathComponent("Irfaali Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let safeExtension = fileExtension.isEmpty ? "mp4" : fileExtension
        return folder.appendingPathComponent("irfaali-\(UUID().uuidString).\(safeExtension)")
    }
}
