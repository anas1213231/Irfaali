@preconcurrency import AVFoundation
import AudioToolbox
import Foundation

/// Explicit video dimensions/cadence and PCM-to-AAC audio, without preset size limits.
enum VideoEncodingService {
    enum EncodingError: LocalizedError {
        case failed(String)
        var errorDescription: String? {
            switch self { case .failed(let detail): return "Video encoding: \(detail)" }
        }
    }

    static func encode(asset: AVAsset, composition: AVVideoComposition?, size: CGSize,
                       fps: Double, hevc: Bool, bitrate: Double, destination: URL,
                       progress: @escaping @Sendable (Double) -> Void) async throws {
        let worker = Task.detached(priority: .userInitiated) {
            try await run(asset: asset, composition: composition, size: size, fps: fps,
                          hevc: hevc, bitrate: bitrate, destination: destination, progress: progress)
        }
        try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
    }

    private static func run(asset: AVAsset, composition: AVVideoComposition?, size: CGSize,
                            fps: Double, hevc: Bool, bitrate: Double, destination: URL,
                            progress: @escaping @Sendable (Double) -> Void) async throws {
        try Task.checkCancellation()
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let video = videoTracks.first else { throw EncodingError.failed("Missing video track") }
        let duration = try await asset.load(.duration)
        let reader = try AVAssetReader(asset: asset)
        let pixels: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        let videoOutput: AVAssetReaderOutput
        if let composition {
            let output = AVAssetReaderVideoCompositionOutput(videoTracks: videoTracks, videoSettings: pixels)
            output.videoComposition = composition
            videoOutput = output
        } else {
            videoOutput = AVAssetReaderTrackOutput(track: video, outputSettings: pixels)
        }
        videoOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(videoOutput) else { throw EncodingError.failed("Cannot decode video") }
        reader.add(videoOutput)
        let writer = try AVAssetWriter(outputURL: destination, fileType: .mp4)
        let targetBitrate = max(2_000_000, min(120_000_000, max(bitrate, Double(size.width * size.height) * fps * (hevc ? 0.08 : 0.14))))
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: hevc ? AVVideoCodecType.hevc : AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: Int(targetBitrate),
                AVVideoExpectedSourceFrameRateKey: fps,
                AVVideoMaxKeyFrameIntervalKey: max(1, Int(fps * 2))]
        ]
        guard writer.canApply(outputSettings: videoSettings, forMediaType: .video) else {
            throw EncodingError.failed("This device cannot encode the requested size and codec")
        }
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        if composition == nil { videoInput.transform = try await video.load(.preferredTransform) }
        guard writer.canAdd(videoInput) else { throw EncodingError.failed("Cannot write video") }
        writer.add(videoInput)

        var pairs: [(AVAssetReaderOutput, AVAssetWriterInput)] = [(videoOutput, videoInput)]
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        if !audioTracks.isEmpty {
            // Mix source tracks at their original timestamps and encode a compatible AAC track.
            let audioOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 2, AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ])
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 192_000
            ])
            audioInput.expectsMediaDataInRealTime = false
            guard reader.canAdd(audioOutput), writer.canAdd(audioInput) else {
                throw EncodingError.failed("Cannot preserve source audio")
            }
            reader.add(audioOutput); writer.add(audioInput)
            pairs.append((audioOutput, audioInput))
        }
        do {
            guard writer.startWriting() else { throw writer.error ?? EncodingError.failed("Cannot start writer") }
            writer.startSession(atSourceTime: .zero)
            guard reader.startReading() else { throw reader.error ?? EncodingError.failed("Cannot start reader") }
            var done = Array(repeating: false, count: pairs.count)
            var counts = Array(repeating: 0, count: pairs.count)
            var lastActivity = Date()
            var lastProgress = Date.distantPast
            while done.contains(false) {
                try Task.checkCancellation()
                if writer.status == .failed { throw writer.error ?? EncodingError.failed("Writer failed") }
                if reader.status == .failed { throw reader.error ?? EncodingError.failed("Reader failed") }
                var advanced = false
                for i in pairs.indices where !done[i] {
                    let (output, input) = pairs[i]
                    guard input.isReadyForMoreMediaData else { continue }
                    if let sample = output.copyNextSampleBuffer() {
                        guard input.append(sample) else { throw writer.error ?? EncodingError.failed("Cannot append sample") }
                        counts[i] += 1
                        if i == 0 && Date().timeIntervalSince(lastProgress) >= 0.1 {
                            lastProgress = Date()
                            let time = CMSampleBufferGetPresentationTimeStamp(sample).seconds
                            progress(min(0.99, max(0, time / max(duration.seconds, 0.001))))
                        }
                    } else {
                        if reader.status == .failed { throw reader.error ?? EncodingError.failed("Decode failed") }
                        input.markAsFinished(); done[i] = true
                    }
                    advanced = true
                }
                if advanced { lastActivity = Date() }
                else {
                    guard Date().timeIntervalSince(lastActivity) < 60 else { throw EncodingError.failed("Encoder stalled") }
                    try await Task.sleep(for: .milliseconds(2))
                }
            }
            guard counts.allSatisfy({ $0 > 0 }) else { throw EncodingError.failed("An output track has no samples") }
            writer.endSession(atSourceTime: duration)
            await writer.finishWriting()
            try Task.checkCancellation()
            guard writer.status == .completed else { throw writer.error ?? EncodingError.failed("Incomplete output") }
            progress(1)
        } catch {
            reader.cancelReading(); writer.cancelWriting()
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }
}
