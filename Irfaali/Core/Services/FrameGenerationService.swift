@preconcurrency import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation

final class FrameGenerationService {
    enum GenerationError: LocalizedError {
        case unsupportedPlan
        case missingVideoTrack
        case invalidVideoDimensions
        case cannotCreateReader
        case cannotAddReaderOutput
        case cannotCreateWriter
        case cannotAddWriterInput
        case readerFailed(String)
        case writerFailed(String)
        case missingImageBuffer
        case appendFailed
        case cannotMuxAudio

        var errorDescription: String? {
            switch self {
            case .unsupportedPlan:
                return "معدل الفريمات المطلوب خارج نطاق التوليد المدعوم (حتى 120 FPS و8× المصدر)."
            case .missingVideoTrack:
                return "ما لقينا مسار فيديو صالح لتوليد الفريمات."
            case .invalidVideoDimensions:
                return "أبعاد الفيديو غير صالحة لتوليد الفريمات."
            case .cannotCreateReader:
                return "تعذر فتح الفيديو للقراءة فريم بفريم."
            case .cannotAddReaderOutput:
                return "تعذر تجهيز مخرج الفريمات من الفيديو."
            case .cannotCreateWriter:
                return "تعذر تجهيز ملف الفيديو الجديد."
            case .cannotAddWriterInput:
                return "تعذر تجهيز مدخل ترميز الفيديو الجديد."
            case .readerFailed(let message):
                return "فشل قراءة الفيديو أثناء توليد الفريمات: \(message)"
            case .writerFailed(let message):
                return "فشل ترميز الفريمات الجديدة: \(message)"
            case .missingImageBuffer:
                return "وصل فريم بدون بيانات صورة قابلة للمعالجة."
            case .appendFailed:
                return "تعذر إضافة فريم مولّد إلى الفيديو النهائي."
            case .cannotMuxAudio:
                return "تم توليد الصورة، لكن تعذر إرجاع مسار الصوت للملف النهائي."
            }
        }
    }

    struct Result: Sendable {
        let url: URL
        let generatedFrameCount: Int
        let sceneCutFallbackFrameCount: Int
        let sourceFrameCount: Int
        let targetFPS: Double
    }

    /// Generates a genuine optical-flow 2× video.
    ///
    /// Normal source-frame gaps receive newly synthesized motion-aware midpoint
    /// frames. Hard scene cuts are detected before optical flow; those gaps use an
    /// explicitly-counted temporal hold so we never create a ghosted cross-shot frame
    /// and never misreport the hold as an AI-generated frame. Audio is muxed back
    /// from the source without changing its timing.
    func generate2x(
        sourceURL: URL,
        sourceFPS: Double,
        targetFPS: Double,
        estimatedBitrate: Double,
        preferHEVC: Bool,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> Result {
        guard let plan = FrameGenerationPlan.make(sourceFPS: sourceFPS, targetFPS: targetFPS),
              plan.strategy == .opticalFlow2x else {
            throw GenerationError.unsupportedPlan
        }

        let worker = Task.detached(priority: .userInitiated) {
            try await Self.performGeneration(
                sourceURL: sourceURL,
                plan: plan,
                estimatedBitrate: estimatedBitrate,
                preferHEVC: preferHEVC,
                progress: progress
            )
        }

        return try await withTaskCancellationHandler(operation: {
            try await worker.value
        }, onCancel: {
            worker.cancel()
        })
    }

    private static func performGeneration(
        sourceURL: URL,
        plan: FrameGenerationPlan,
        estimatedBitrate: Double,
        preferHEVC: Bool,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> Result {
        try Task.checkCancellation()

        let sourceAsset = AVURLAsset(url: sourceURL)
        let tracks = try await sourceAsset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            throw GenerationError.missingVideoTrack
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let width = Int(abs(naturalSize.width).rounded())
        let height = Int(abs(naturalSize.height).rounded())
        guard width > 1, height > 1 else {
            throw GenerationError.invalidVideoDimensions
        }

        let videoTimeRange = try await videoTrack.load(.timeRange)
        let durationSeconds = max(CMTimeGetSeconds(videoTimeRange.duration), 0.001)

        let silentURL = try makeDestination(prefix: "irfaali-framegen-silent")
        let finalURL = try makeDestination(prefix: "irfaali-framegen")
        try? FileManager.default.removeItem(at: silentURL)
        try? FileManager.default.removeItem(at: finalURL)

        var activeReader: AVAssetReader?
        var activeWriter: AVAssetWriter?

        do {
            let reader: AVAssetReader
            do {
                reader = try AVAssetReader(asset: sourceAsset)
            } catch {
                throw GenerationError.cannotCreateReader
            }
            activeReader = reader

            let readerOutput = AVAssetReaderTrackOutput(
                track: videoTrack,
                outputSettings: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
            )
            readerOutput.alwaysCopiesSampleData = false
            guard reader.canAdd(readerOutput) else {
                throw GenerationError.cannotAddReaderOutput
            }
            reader.add(readerOutput)

            let writer: AVAssetWriter
            do {
                writer = try AVAssetWriter(outputURL: silentURL, fileType: .mp4)
            } catch {
                throw GenerationError.cannotCreateWriter
            }
            activeWriter = writer

            let requestedBitrate = Int(
                VideoEncodingQualityPolicy.targetBitrate(
                    size: CGSize(width: width, height: height),
                    fps: plan.targetFPS,
                    hevc: preferHEVC,
                    sourceBitrate: estimatedBitrate.isFinite ? estimatedBitrate : 0
                )
            )

            let codec: AVVideoCodecType = preferHEVC ? .hevc : .h264
            let writerInput = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: [
                    AVVideoCodecKey: codec,
                    AVVideoWidthKey: width,
                    AVVideoHeightKey: height,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: requestedBitrate,
                        AVVideoExpectedSourceFrameRateKey: Int(plan.targetFPS.rounded()),
                        AVVideoMaxKeyFrameIntervalKey: max(1, Int(plan.targetFPS.rounded() * 2))
                    ]
                ]
            )
            writerInput.expectsMediaDataInRealTime = false
            writerInput.transform = preferredTransform

            guard writer.canAdd(writerInput) else {
                throw GenerationError.cannotAddWriterInput
            }
            writer.add(writerInput)

            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: writerInput,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: width,
                    kCVPixelBufferHeightKey as String: height,
                    kCVPixelBufferMetalCompatibilityKey as String: true
                ]
            )

            guard writer.startWriting() else {
                throw GenerationError.writerFailed(writer.error?.localizedDescription ?? "startWriting failed")
            }
            writer.startSession(atSourceTime: .zero)

            guard reader.startReading() else {
                writer.cancelWriting()
                throw GenerationError.readerFailed(reader.error?.localizedDescription ?? "startReading failed")
            }

            let opticalFlow = OpticalFlowService()
            let synthesizer = try MotionWarpFrameSynthesizer()
            let cutDetector = SceneCutDetector()

            var previousBuffer: CVPixelBuffer?
            var previousPTS: CMTime?
            var originPTS: CMTime?
            var nextOutputIndex = 0
            var sourceFrameCount = 0
            var generatedFrameCount = 0
            var sceneCutFallbackFrameCount = 0

            while let sample = readerOutput.copyNextSampleBuffer() {
                try Task.checkCancellation()

                guard let currentBuffer = CMSampleBufferGetImageBuffer(sample) else {
                    reader.cancelReading()
                    writer.cancelWriting()
                    throw GenerationError.missingImageBuffer
                }

                let currentPTS = CMSampleBufferGetPresentationTimeStamp(sample)
                if originPTS == nil {
                    originPTS = currentPTS
                }

                if let previousBuffer, let previousPTS, let originPTS {
                    try autoreleasepool {
                    let start = CMTimeSubtract(previousPTS, originPTS).seconds
                    let end = CMTimeSubtract(currentPTS, originPTS).seconds
                    let cut = cutDetector.evaluate(previous: previousBuffer, current: currentBuffer)
                    let samples = plan.samples(from: start, to: end, nextIndex: &nextOutputIndex)
                    var forward: CVPixelBuffer?
                    var backward: CVPixelBuffer?
                    for sample in samples {
                        try Task.checkCancellation()
                        let time = CMTime(seconds: sample.time, preferredTimescale: 60_000)
                        if sample.fraction < 0.000001 {
                            try append(previousBuffer, at: time, adaptor: adaptor, writerInput: writerInput, writer: writer)
                            sourceFrameCount += 1
                        } else if cut.isCut {
                            try append(previousBuffer, at: time, adaptor: adaptor, writerInput: writerInput, writer: writer)
                            sceneCutFallbackFrameCount += 1
                        } else {
                            if forward == nil {
                                forward = try opticalFlow.generateFlow(from: previousBuffer, to: currentBuffer, accuracy: .high)
                                backward = try opticalFlow.generateFlow(from: currentBuffer, to: previousBuffer, accuracy: .high)
                            }
                            let frame = try synthesizer.synthesize(source: previousBuffer, target: currentBuffer,
                                forwardFlow: forward!, backwardFlow: backward!, fraction: sample.fraction)
                            try append(frame, at: time, adaptor: adaptor, writerInput: writerInput, writer: writer)
                            generatedFrameCount += 1
                        }
                    }

                    }
                    let adjustedCurrent = CMTimeSubtract(currentPTS, originPTS)
                    let seconds = max(0, CMTimeGetSeconds(adjustedCurrent))
                    progress(min(max((seconds / durationSeconds) * 0.88, 0), 0.88))
                }

                previousBuffer = currentBuffer
                previousPTS = currentPTS
            }

            try Task.checkCancellation()

            if reader.status == .failed {
                writer.cancelWriting()
                throw GenerationError.readerFailed(reader.error?.localizedDescription ?? "Unknown reader failure")
            }

            if let previousBuffer, let previousPTS, let originPTS {
                let start = CMTimeSubtract(previousPTS, originPTS).seconds
                let end = max(start, durationSeconds)
                for sample in plan.samples(from: start, to: end, nextIndex: &nextOutputIndex) {
                    try append(previousBuffer, at: CMTime(seconds: sample.time, preferredTimescale: 60_000),
                        adaptor: adaptor, writerInput: writerInput, writer: writer)
                    if sample.fraction < 0.000001 { sourceFrameCount += 1 }
                    else { sceneCutFallbackFrameCount += 1 } // Hold the last image through its remaining duration.
                }
            }
            writer.endSession(atSourceTime: CMTime(seconds: durationSeconds, preferredTimescale: 60_000))

            writerInput.markAsFinished()
            try Task.checkCancellation()
            try await finish(writer)
            activeWriter = nil
            activeReader = nil
            progress(0.9)

            try Task.checkCancellation()
            let muxedURL = try await muxOriginalAudio(
                generatedVideoURL: silentURL,
                originalURL: sourceURL,
                destinationURL: finalURL
            )
            try? FileManager.default.removeItem(at: silentURL)
            try Task.checkCancellation()
            progress(1)

            return Result(
                url: muxedURL,
                generatedFrameCount: generatedFrameCount,
                sceneCutFallbackFrameCount: sceneCutFallbackFrameCount,
                sourceFrameCount: sourceFrameCount,
                targetFPS: plan.targetFPS
            )
        } catch {
            activeReader?.cancelReading()
            activeWriter?.cancelWriting()
            try? FileManager.default.removeItem(at: silentURL)
            try? FileManager.default.removeItem(at: finalURL)
            throw error
        }
    }

    private static func append(
        _ pixelBuffer: CVPixelBuffer,
        at presentationTime: CMTime,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        writerInput: AVAssetWriterInput,
        writer: AVAssetWriter
    ) throws {
        try Task.checkCancellation()

        let deadline = Date().addingTimeInterval(30)
        while !writerInput.isReadyForMoreMediaData {
            guard Date() < deadline else {
                throw GenerationError.writerFailed("The encoder stopped accepting frames for 30 seconds.")
            }
            try Task.checkCancellation()
            if writer.status == .failed {
                throw GenerationError.writerFailed(writer.error?.localizedDescription ?? "Writer became unavailable")
            }
            if writer.status == .cancelled {
                throw CancellationError()
            }
            Thread.sleep(forTimeInterval: 0.0015)
        }

        guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
            if let error = writer.error {
                throw GenerationError.writerFailed(error.localizedDescription)
            }
            throw GenerationError.appendFailed
        }
    }

    private static func finish(_ writer: AVAssetWriter) async throws {
        try Task.checkCancellation()

        try await withTaskCancellationHandler(operation: {
            await withCheckedContinuation { continuation in
                writer.finishWriting {
                    continuation.resume()
                }
            }

            guard writer.status == .completed else {
                if writer.status == .cancelled {
                    throw CancellationError()
                }
                throw GenerationError.writerFailed(writer.error?.localizedDescription ?? "finishWriting failed")
            }
        }, onCancel: {
            writer.cancelWriting()
        })
    }

    private static func muxOriginalAudio(
        generatedVideoURL: URL,
        originalURL: URL,
        destinationURL: URL
    ) async throws -> URL {
        try Task.checkCancellation()

        let generatedAsset = AVURLAsset(url: generatedVideoURL)
        let originalAsset = AVURLAsset(url: originalURL)
        let generatedTracks = try await generatedAsset.loadTracks(withMediaType: .video)
        guard let generatedTrack = generatedTracks.first else {
            throw GenerationError.missingVideoTrack
        }

        let originalVideoTracks = try await originalAsset.loadTracks(withMediaType: .video)
        guard let originalVideoTrack = originalVideoTracks.first else {
            throw GenerationError.missingVideoTrack
        }

        let generatedRange = try await generatedTrack.load(.timeRange)
        let originalVideoRange = try await originalVideoTrack.load(.timeRange)
        guard generatedRange.duration.seconds.isFinite, generatedRange.duration.seconds > 0 else {
            throw GenerationError.cannotMuxAudio
        }

        let audioTracks = try await originalAsset.loadTracks(withMediaType: .audio)
        var audioEntries: [(track: AVAssetTrack, range: CMTimeRange)] = []
        var earliestStart = originalVideoRange.start

        for audioTrack in audioTracks {
            try Task.checkCancellation()
            let audioRange = try await audioTrack.load(.timeRange)
            guard audioRange.start.isValid,
                  audioRange.start.isNumeric,
                  audioRange.duration.seconds.isFinite,
                  audioRange.duration.seconds > 0 else {
                throw GenerationError.cannotMuxAudio
            }
            audioEntries.append((audioTrack, audioRange))
            if CMTimeCompare(audioRange.start, earliestStart) < 0 {
                earliestStart = audioRange.start
            }
        }

        let timelineShift: CMTime
        if earliestStart.isValid,
           earliestStart.isNumeric,
           CMTimeCompare(earliestStart, .zero) < 0 {
            timelineShift = CMTimeSubtract(.zero, earliestStart)
        } else {
            timelineShift = .zero
        }

        let composition = AVMutableComposition()
        guard let videoCompositionTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw GenerationError.cannotMuxAudio
        }

        try videoCompositionTrack.insertTimeRange(
            generatedRange,
            of: generatedTrack,
            at: CMTimeAdd(originalVideoRange.start, timelineShift)
        )

        videoCompositionTrack.preferredTransform = try await generatedTrack.load(.preferredTransform)

        for entry in audioEntries {
            try Task.checkCancellation()
            guard let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else { throw GenerationError.cannotMuxAudio }
            try compositionAudioTrack.insertTimeRange(
                entry.range,
                of: entry.track,
                at: CMTimeAdd(entry.range.start, timelineShift)
            )
        }

        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough),
              exporter.supportedFileTypes.contains(.mp4) else {
            throw GenerationError.cannotMuxAudio
        }
        exporter.outputURL = destinationURL
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = true

        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                exporter.exportAsynchronously {
                    switch exporter.status {
                    case .completed:
                        continuation.resume()
                    case .failed:
                        continuation.resume(throwing: GenerationError.cannotMuxAudio)
                    case .cancelled:
                        continuation.resume(throwing: CancellationError())
                    default:
                        continuation.resume(throwing: GenerationError.cannotMuxAudio)
                    }
                }
            }
        }, onCancel: {
            exporter.cancelExport()
        })

        try Task.checkCancellation()
        return destinationURL
    }

    private static func makeDestination(prefix: String) throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = documents.appendingPathComponent("Irfaali Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("\(prefix)-\(UUID().uuidString).mp4")
    }
}
