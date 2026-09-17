@preconcurrency import AVFoundation
import AVFAudio
import XCTest
@testable import Irfaali

final class SourceTimelineExportTests: XCTestCase {
    func testFinalExportPreservesSourceRelativeAVOffsets() async throws {
        let source = try await makeOffsetFixture(videoStart: 0.20, audioStart: 0.32)
        defer { remove(source) }

        let sourceOffsets = try await avOffsets(url: source)
        XCTAssertEqual(sourceOffsets.start, 0.12, accuracy: 0.03)
        XCTAssertEqual(sourceOffsets.end, 0.12, accuracy: 0.04)

        let info = try await VideoAnalyzer().analyze(url: source)
        let settings = VideoProcessingSettings(
            resolution: .source,
            frameRate: .source,
            codec: .h264
        )
        let result = try await VideoExportService().export(
            info: info,
            settings: settings
        ) { _ in }
        defer { remove(result.url) }

        let outputOffsets = try await avOffsets(url: result.url)
        XCTAssertEqual(outputOffsets.start, sourceOffsets.start, accuracy: 0.05)
        XCTAssertEqual(outputOffsets.end, sourceOffsets.end, accuracy: 0.08)

        let report = try await AudioIntegrityAudit.verify(
            sourceURL: source,
            outputURL: result.url
        )
        XCTAssertTrue(report.passed, report.mismatchReason ?? "A/V timeline audit failed")

        let outputInfo = try await VideoAnalyzer().analyze(url: result.url)
        XCTAssertEqual(outputInfo.duration, info.duration, accuracy: 0.08)
    }

    private func makeOffsetFixture(videoStart: Double, audioStart: Double) async throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("irfaali-timeline-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let videoURL = folder.appendingPathComponent("video.mov")
        try await writeVideo(to: videoURL)

        let audioURL = folder.appendingPathComponent("tone.wav")
        try writeTone(to: audioURL)

        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioURL)
        let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
        let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
        let videoTrack = try XCTUnwrap(videoTracks.first)
        let audioTrack = try XCTUnwrap(audioTracks.first)
        let videoRange = try await videoTrack.load(.timeRange)
        let audioRange = try await audioTrack.load(.timeRange)

        let composition = AVMutableComposition()
        let compositionVideo = try XCTUnwrap(composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ))
        let compositionAudio = try XCTUnwrap(composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ))

        try compositionVideo.insertTimeRange(
            videoRange,
            of: videoTrack,
            at: CMTime(seconds: videoStart, preferredTimescale: 1_000)
        )
        compositionVideo.preferredTransform = try await videoTrack.load(.preferredTransform)
        try compositionAudio.insertTimeRange(
            audioRange,
            of: audioTrack,
            at: CMTime(seconds: audioStart, preferredTimescale: 1_000)
        )

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("irfaali-offset-\(UUID().uuidString).mp4")
        let session = try XCTUnwrap(
            AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
        )
        session.outputURL = destination
        session.outputFileType = .mp4
        await session.export()
        guard session.status == .completed else {
            remove(destination)
            throw session.error ?? FixtureError.failed("Offset fixture export failed")
        }
        return destination
    }

    private func writeVideo(to url: URL) async throws {
        let fps = 30
        let width = 64
        let height = 36
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height
            ]
        )
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )
        guard writer.canAdd(input) else { throw FixtureError.failed("Cannot add video input") }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? FixtureError.failed("Cannot start video writer") }
        writer.startSession(atSourceTime: .zero)

        for index in 0..<fps {
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing else {
                    throw writer.error ?? FixtureError.failed("Video writer stopped")
                }
                try await Task.sleep(for: .milliseconds(1))
            }

            var pixelBuffer: CVPixelBuffer?
            guard let pool = adaptor.pixelBufferPool,
                  CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer) == kCVReturnSuccess,
                  let pixelBuffer else {
                throw FixtureError.failed("Cannot allocate fixture frame")
            }

            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            let base = CVPixelBufferGetBaseAddress(pixelBuffer)!.assumingMemoryBound(to: UInt8.self)
            let stride = CVPixelBufferGetBytesPerRow(pixelBuffer)
            for y in 0..<height {
                for x in 0..<width {
                    let offset = y * stride + x * 4
                    base[offset] = UInt8((x + index * 2) % 255)
                    base[offset + 1] = UInt8((y * 4) % 255)
                    base[offset + 2] = UInt8((index * 7) % 255)
                    base[offset + 3] = 255
                }
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

            guard adaptor.append(
                pixelBuffer,
                withPresentationTime: CMTime(value: Int64(index), timescale: Int32(fps))
            ) else {
                throw writer.error ?? FixtureError.failed("Cannot append fixture frame")
            }
        }

        writer.endSession(atSourceTime: CMTime(seconds: 1, preferredTimescale: 600))
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw writer.error ?? FixtureError.failed("Fixture video encoding failed")
        }
    }

    private func writeTone(to url: URL) throws {
        let format = try XCTUnwrap(AVAudioFormat(
            standardFormatWithSampleRate: 48_000,
            channels: 1
        ))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: 48_000
        ))
        buffer.frameLength = 48_000
        let samples = try XCTUnwrap(buffer.floatChannelData)[0]
        for index in 0..<48_000 {
            samples[index] = Float(
                sin(Double(index) * 2 * Double.pi * 440 / 48_000) * 0.2
            )
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }

    private func avOffsets(url: URL) async throws -> (start: Double, end: Double) {
        let asset = AVURLAsset(url: url)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let video = try XCTUnwrap(videoTracks.first)
        let audio = try XCTUnwrap(audioTracks.first)
        let videoRange = try await mediaRange(for: video)
        let audioRange = try await mediaRange(for: audio)
        return (
            audioRange.start.seconds - videoRange.start.seconds,
            CMTimeRangeGetEnd(audioRange).seconds - CMTimeRangeGetEnd(videoRange).seconds
        )
    }

    private func mediaRange(for track: AVAssetTrack) async throws -> CMTimeRange {
        let segments = try await track.load(.segments).filter { !$0.isEmpty }
        guard let first = segments.first else {
            throw FixtureError.failed("Track has no non-empty media segments")
        }

        var start = first.timeMapping.target.start
        var end = CMTimeRangeGetEnd(first.timeMapping.target)
        for segment in segments.dropFirst() {
            let range = segment.timeMapping.target
            if CMTimeCompare(range.start, start) < 0 {
                start = range.start
            }
            let candidateEnd = CMTimeRangeGetEnd(range)
            if CMTimeCompare(candidateEnd, end) > 0 {
                end = candidateEnd
            }
        }

        return CMTimeRange(
            start: start,
            duration: CMTimeSubtract(end, start)
        )
    }

    private func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private enum FixtureError: LocalizedError {
        case failed(String)
        var errorDescription: String? {
            switch self {
            case .failed(let message): return message
            }
        }
    }
}
