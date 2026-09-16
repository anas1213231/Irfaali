@preconcurrency import AVFoundation
import CoreGraphics
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
        case missingVideoTrack
        case cannotCreateCompositionTrack
        case frameGenerationRequired(requested: Double, source: Double)
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .cannotCreateSession:
                return "تعذر إنشاء جلسة التصدير لهذا الفيديو."
            case .unsupportedOutputType:
                return "صيغة الإخراج المطلوبة غير مدعومة لهذا الملف."
            case .missingVideoTrack:
                return "ما لقينا مسار فيديو صالح داخل الملف."
            case .cannotCreateCompositionTrack:
                return "تعذر تجهيز مسار المعالجة للفيديو."
            case .frameGenerationRequired(let requested, let source):
                return "الفيديو مصدره \(Int(source.rounded())) FPS وطلبت \(Int(requested.rounded())) FPS. رفع الفريمات يحتاج توليد إطارات حقيقي، لذلك ارفعلي ما راح يزوّر الرقم أو يكرر نفس الفريم."
            case .failed(let message):
                return "فشل التصدير: \(message)"
            }
        }
    }

    func export(
        info: VideoAssetInfo,
        settings: VideoProcessingSettings,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> ExportOutcome {
        try Task.checkCancellation()

        if settings.isPassThrough(for: info) {
            let destination = try uniqueDestination(extension: info.url.pathExtension.isEmpty ? "mp4" : info.url.pathExtension)
            do {
                try FileManager.default.copyItem(at: info.url, to: destination)
                try Task.checkCancellation()
                progress(1)
            } catch {
                try? FileManager.default.removeItem(at: destination)
                throw error
            }

            return ExportOutcome(
                url: destination,
                sourceFPS: info.sourceFPS,
                outputFPS: info.sourceFPS,
                fpsMode: .preserved,
                codecLabel: info.videoCodec
            )
        }

        if settings.needsFrameGeneration(for: info), let requested = settings.frameRate.requestedFPS {
            throw ExportError.frameGenerationRequired(requested: requested, source: info.sourceFPS)
        }

        let sourceAsset = AVURLAsset(url: info.url)
        let outputFPS = settings.effectiveFPS(for: info)
        let targetSize = settings.targetSize(for: info)

        // Every encoded result is normalized through an explicit composition so
        // portrait orientation, requested dimensions and cadence stay measurable.
        let prepared = try await prepareComposition(
            sourceAsset: sourceAsset,
            info: info,
            targetSize: targetSize,
            outputFPS: outputFPS
        )
        let exportAsset: AVAsset = prepared.asset
        let videoComposition: AVMutableVideoComposition = prepared.videoComposition

        try Task.checkCancellation()

        let destination = try uniqueDestination(extension: "mp4")
        let useHEVC = resolvedCodec(settings: settings, info: info) == .hevc

        do {
            // Production quality path: explicit reader/writer encoding gives Irfaali
            // deterministic codec, dimensions, cadence and bitrate guardrails. This
            // prevents a high-quality restoration from being weakened by an opaque
            // export-preset bitrate decision at the final stage.
            try await VideoEncodingService.encode(
                asset: exportAsset,
                composition: videoComposition,
                size: targetSize,
                fps: outputFPS,
                hevc: useHEVC,
                bitrate: info.estimatedBitrate,
                destination: destination,
                progress: progress
            )

            try Task.checkCancellation()
            let encodedInfo = try await VideoAnalyzer().analyze(url: destination)
            if let mismatch = OutputVerification.mismatch(
                source: info,
                output: encodedInfo,
                settings: settings
            ) {
                throw ExportError.failed("Primary encoder output mismatch: \(mismatch)")
            }
            progress(1)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Keep AVAssetExportSession as a compatibility fallback for devices or
            // media combinations rejected by the explicit reader/writer path.
            try? FileManager.default.removeItem(at: destination)
            try await AVAssetExportEngine.export(
                asset: exportAsset,
                videoComposition: videoComposition,
                targetSize: targetSize,
                fps: outputFPS,
                useHEVC: useHEVC,
                destination: destination,
                progress: progress
            )

            try Task.checkCancellation()
            let fallbackInfo = try await VideoAnalyzer().analyze(url: destination)
            if let mismatch = OutputVerification.mismatch(
                source: info,
                output: fallbackInfo,
                settings: settings
            ) {
                try? FileManager.default.removeItem(at: destination)
                throw ExportError.failed("Fallback export output mismatch: \(mismatch)")
            }
        }

        let fpsMode: FPSGenerationMode = outputFPS < info.sourceFPS - 0.5 ? .retimed : .preserved
        return ExportOutcome(
            url: destination,
            sourceFPS: info.sourceFPS,
            outputFPS: outputFPS,
            fpsMode: fpsMode,
            codecLabel: codecLabel(settings: settings, info: info)
        )
    }

    // Kept during the v1 migration so older call sites/tests remain buildable.
    func export(
        info: VideoAssetInfo,
        preset: OptimizationPreset,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> ExportOutcome {
        let settings: VideoProcessingSettings
        switch preset.codec {
        case .passthrough:
            settings = VideoProcessingSettings(resolution: .source, frameRate: .source, codec: .source)
        case .h264:
            let frameRate: VideoProcessingSettings.FrameRate = preset.maximumFPS == 60 ? .fps60 : .source
            settings = VideoProcessingSettings(resolution: .source, frameRate: frameRate, codec: .h264)
        case .hevc:
            settings = VideoProcessingSettings(resolution: .source, frameRate: .source, codec: .hevc)
        }
        return try await export(info: info, settings: settings, progress: progress)
    }

    private func prepareComposition(
        sourceAsset: AVURLAsset,
        info: VideoAssetInfo,
        targetSize: CGSize,
        outputFPS: Double
    ) async throws -> (asset: AVMutableComposition, videoComposition: AVMutableVideoComposition) {
        try Task.checkCancellation()

        let duration = try await sourceAsset.load(.duration)
        let sourceVideoTracks = try await sourceAsset.loadTracks(withMediaType: .video)
        guard let sourceVideoTrack = sourceVideoTracks.first else {
            throw ExportError.missingVideoTrack
        }

        let composition = AVMutableComposition()
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ExportError.cannotCreateCompositionTrack
        }

        try compositionVideoTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: sourceVideoTrack,
            at: .zero
        )

        let sourceAudioTracks = try await sourceAsset.loadTracks(withMediaType: .audio)
        for sourceAudioTrack in sourceAudioTracks {
            try Task.checkCancellation()
            guard let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else { throw ExportError.cannotCreateCompositionTrack }
            let audioRange = try await sourceAudioTrack.load(.timeRange)
            let range = CMTimeRangeGetIntersection(audioRange, otherRange: CMTimeRange(start: .zero, duration: duration))
            if range.duration.seconds > 0 {
                try compositionAudioTrack.insertTimeRange(range, of: sourceAudioTrack, at: range.start)
            }
        }

        let naturalSize = try await sourceVideoTrack.load(.naturalSize)
        let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
        let transformedRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let orientedWidth = max(abs(transformedRect.width), 1)
        let orientedHeight = max(abs(transformedRect.height), 1)

        var normalizedTransform = preferredTransform.concatenating(
            CGAffineTransform(
                translationX: -transformedRect.origin.x,
                y: -transformedRect.origin.y
            )
        )

        normalizedTransform = normalizedTransform.concatenating(
            CGAffineTransform(
                scaleX: targetSize.width / orientedWidth,
                y: targetSize.height / orientedHeight
            )
        )

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        layerInstruction.setTransform(normalizedTransform, at: .zero)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        instruction.layerInstructions = [layerInstruction]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = targetSize
        let safeFPS = max(1, min(outputFPS, 240))
        videoComposition.frameDuration = CMTime(seconds: 1 / safeFPS, preferredTimescale: 60_000)
        videoComposition.instructions = [instruction]

        try Task.checkCancellation()
        return (composition, videoComposition)
    }

    private func resolvedCodec(
        settings: VideoProcessingSettings,
        info: VideoAssetInfo
    ) -> VideoProcessingSettings.Codec {
        if settings.codec != .source { return settings.codec }
        let sourceIsHEVC = info.videoCodec.localizedCaseInsensitiveContains("HEVC") || info.videoCodec.localizedCaseInsensitiveContains("H.265")
        return sourceIsHEVC ? .hevc : .h264
    }

    private func codecLabel(
        settings: VideoProcessingSettings,
        info: VideoAssetInfo
    ) -> String {
        switch resolvedCodec(settings: settings, info: info) {
        case .source:
            return info.videoCodec
        case .h264:
            return "H.264 / AVC"
        case .hevc:
            return "H.265 / HEVC"
        }
    }

    private func uniqueDestination(extension fileExtension: String) throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = documents.appendingPathComponent("Irfaali Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let safeExtension = fileExtension.isEmpty ? "mp4" : fileExtension
        return folder.appendingPathComponent("irfaali-\(UUID().uuidString).\(safeExtension)")
    }
}
