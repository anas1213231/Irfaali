@preconcurrency import AVFoundation
import XCTest
@testable import Irfaali

/// Exercises the production services with real, locally generated media.
/// These checks do not replace physical-device optical-flow/visual QA.
final class VideoPipelineIntegrationTests: XCTestCase {
    func testOriginalCopyPreservesEveryByte() async throws {
        let source = try await makeFixture()
        defer { remove(source) }
        let info = try await VideoAnalyzer().analyze(url: source)
        let settings = VideoProcessingSettings(resolution: .source, frameRate: .source, codec: .source)
        let result = try await VideoExportService().export(info: info, settings: settings) { _ in }
        defer { remove(result.url) }

        XCTAssertNotEqual(result.url, source)
        XCTAssertEqual(try Data(contentsOf: result.url), try Data(contentsOf: source))
        XCTAssertEqual(result.fpsMode, .preserved)
    }

    func testRotated60To30ExportPreservesAudioAndDecodes() async throws {
        let source = try await makeFixture(rotated: true)
        defer { remove(source) }
        let input = try await VideoAnalyzer().analyze(url: source)
        XCTAssertEqual(input.width, 180)
        XCTAssertEqual(input.height, 320)
        XCTAssertNotNil(input.audioCodec)

        let settings = VideoProcessingSettings(resolution: .source, frameRate: .fps30, codec: .h264)
        let result = try await VideoExportService().export(info: input, settings: settings) { _ in }
        defer { remove(result.url) }
        let output = try await VideoAnalyzer().analyze(url: result.url)

        XCTAssertEqual(output.width, input.width)
        XCTAssertEqual(output.height, input.height)
        XCTAssertEqual(output.sourceFPS, 30, accuracy: 0.5)
        XCTAssertEqual(output.duration, input.duration, accuracy: 0.08)
        XCTAssertEqual(output.videoCodec, "H.264 / AVC")
        XCTAssertEqual(result.fpsMode, .retimed)
        try await assertAudioTiming(url: result.url)
        let frames = try await decodedFrameCount(url: result.url)
        XCTAssertEqual(frames, 30)
        let encodedFrames = try await VideoSampleAudit.frameCount(url: result.url)
        XCTAssertEqual(encodedFrames, frames)
    }

    func testEnhancementProducesDecodableVideoWithAudio() async throws {
        let source = try await makeFixture()
        defer { remove(source) }
        let input = try await VideoAnalyzer().analyze(url: source)
        let result = try await VideoEnhancementService().enhance(
            sourceURL: source,
            settings: .smart(for: input),
            preferHEVC: false
        ) { _ in }
        defer { if result != source { remove(result) } }
        XCTAssertNotEqual(result, source)
        let output = try await VideoAnalyzer().analyze(url: result)
        XCTAssertEqual(output.width, input.width)
        XCTAssertEqual(output.height, input.height)
        XCTAssertEqual(output.sourceFPS, input.sourceFPS, accuracy: 0.5)
        XCTAssertEqual(output.duration, input.duration, accuracy: 0.08)
        try await assertAudioTiming(url: result)
        let frames = try await decodedFrameCount(url: result)
        XCTAssertEqual(frames, 60)
    }

    func testCancelledExportLeavesSourceIntact() async throws {
        let source = try await makeFixture()
        defer { remove(source) }
        let input = try await VideoAnalyzer().analyze(url: source)
        let original = try Data(contentsOf: source)
        // Cancel deterministically before service entry; mid-stage cancellation
        // is a separate device QA requirement.
        let task = Task { () throws -> ExportOutcome in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await VideoExportService().export(info: input, settings: .standard) { _ in }
        }
        do {
            let unexpected = try await task.value
            remove(unexpected.url)
            XCTFail("A cancelled export returned a completed file")
        } catch is CancellationError {
            XCTAssertEqual(try Data(contentsOf: source), original)
        }
    }

    func testPortrait4KExportEncodesRequestedDimensions() async throws {
        let source = try await makeFixture(rotated: true)
        defer { remove(source) }
        let input = try await VideoAnalyzer().analyze(url: source)
        let settings = VideoProcessingSettings(resolution: .ultraHD, frameRate: .fps30, codec: .h264)
        let result = try await VideoExportService().export(info: input, settings: settings) { _ in }
        defer { remove(result.url) }
        let output = try await VideoAnalyzer().analyze(url: result.url)
        XCTAssertEqual(output.width, 2160)
        XCTAssertEqual(output.height, 3840)
        XCTAssertNil(OutputVerification.mismatch(source: input, output: output, settings: settings))
        let frames = try await decodedFrameCount(url: result.url)
        XCTAssertEqual(frames, 30)
        try await assertAudioTiming(url: result.url)
    }

    func testVerifierRejectsUnprocessedFileFor4KAndHigherFPSRequests() async throws {
        let source = try await makeFixture()
        defer { remove(source) }
        let input = try await VideoAnalyzer().analyze(url: source)
        XCTAssertNotNil(OutputVerification.mismatch(
            source: input, output: input,
            settings: VideoProcessingSettings(resolution: .ultraHD, frameRate: .source, codec: .h264)
        ))
        XCTAssertNotNil(OutputVerification.mismatch(
            source: input, output: input,
            settings: VideoProcessingSettings(resolution: .source, frameRate: .fps120, codec: .h264)
        ))
        XCTAssertNil(OutputVerification.mismatch(
            source: input, output: input,
            settings: VideoProcessingSettings(resolution: .source, frameRate: .source, codec: .source)
        ))
    }

    @MainActor
    func testEditorLanguageSnapshotsAndPlaybackAudioPolicy() async throws {
        let source = try await makeFixture(rotated: true)
        defer { remove(source) }
        let model = StudioViewModel()
        await model.importVideo(url: source)
        let preferences = AppPreferences(defaults: UserDefaults(suiteName: "editor-test")!)
        preferences.animationsEnabled = false
        preferences.appearance = .dark
        for language in AppPreferences.Language.allCases {
            preferences.language = language
            try await InterfaceSnapshotTests.capture(StudioView(model: model), preferences: preferences, label: "editor-\(language.rawValue)")
        }
        let playback = VideoPlaybackController()
        playback.load(url: source, enhancement: .off)
        defer { playback.stop() }
        XCTAssertNil(playback.error)
        XCTAssertEqual(AVAudioSession.sharedInstance().category, .playback)
        XCTAssertEqual(AVAudioSession.sharedInstance().mode, .moviePlayback)
        XCTAssertFalse(playback.player.isMuted)
        XCTAssertEqual(playback.player.volume, 1)
    }

    func testExposureActuallyChangesDecodedPixelsAndKeepsAudio() async throws {
        let source = try await makeFixture()
        defer { remove(source) }
        var settings = VideoEnhancementSettings.off
        settings.mode = .custom
        settings.exposure = 0.7
        let result = try await VideoEnhancementService().enhance(sourceURL: source, settings: settings, preferHEVC: false) { _ in }
        defer { remove(result) }
        let before = try await averagePixelValue(source)
        let after = try await averagePixelValue(result)
        XCTAssertGreaterThan(after, before + 10, "The encoded pixels must reflect the exposure adjustment")
        try await assertAudioTiming(url: result)
    }

    func testMotionInterpolation30To60EncodesNewFramesAndAudio() async throws {
        let source = try await makeFixture()
        defer { remove(source) }
        let info = try await VideoAnalyzer().analyze(url: source)
        let reduced = try await VideoExportService().export(info: info, settings: .init(resolution: .source, frameRate: .fps30, codec: .h264)) { _ in }
        defer { remove(reduced.url) }
        let generated: FrameGenerationService.Result
        do {
            generated = try await FrameGenerationService().generate2x(sourceURL: reduced.url, sourceFPS: 30, targetFPS: 60, estimatedBitrate: info.estimatedBitrate, preferHEVC: false) { _ in }
        } catch {
            #if targetEnvironment(simulator)
            let ns = error as NSError
            if ns.domain == "com.apple.vis", ns.code == 9 {
                throw XCTSkip("Vision optical flow is unavailable in this simulator: \(ns.localizedDescription). Physical iPhone verification remains required.")
            }
            #endif
            throw error
        }
        defer { remove(generated.url) }
        XCTAssertGreaterThan(generated.generatedFrameCount, 0)
        let count = try await decodedFrameCount(url: generated.url)
        XCTAssertEqual(count, generated.sourceFrameCount + generated.generatedFrameCount + generated.sceneCutFallbackFrameCount)
        let output = try await VideoAnalyzer().analyze(url: generated.url)
        XCTAssertEqual(output.sourceFPS, 60, accuracy: 0.5)
        try await assertAudioTiming(url: generated.url)
    }

    private func averagePixelValue(_ url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: try XCTUnwrap(tracks.first), outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        reader.add(output)
        XCTAssertTrue(reader.startReading())
        defer { reader.cancelReading() }
        let sample = try XCTUnwrap(output.copyNextSampleBuffer())
        let pixel = try XCTUnwrap(CMSampleBufferGetImageBuffer(sample))
        CVPixelBufferLockBaseAddress(pixel, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixel, .readOnly) }
        let base = CVPixelBufferGetBaseAddress(pixel)!.assumingMemoryBound(to: UInt8.self)
        let stride = CVPixelBufferGetBytesPerRow(pixel)
        let width = CVPixelBufferGetWidth(pixel), height = CVPixelBufferGetHeight(pixel)
        var sum = 0.0
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * stride + x * 4
                sum += Double(base[offset]) + Double(base[offset + 1]) + Double(base[offset + 2])
            }
        }
        return sum / Double(width * height * 3)
    }

    private func makeFixture(rotated: Bool = false) async throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let silentURL = folder.appendingPathComponent("video.mov")
        let writer = try AVAssetWriter(outputURL: silentURL, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 320,
            AVVideoHeightKey: 180
        ])
        input.expectsMediaDataInRealTime = false
        if rotated {
            input.transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 180, ty: 0)
        }
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 320,
                kCVPixelBufferHeightKey as String: 180
            ]
        )
        guard writer.canAdd(input) else { throw FixtureError.failed("Cannot add video input") }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? FixtureError.failed("Cannot start writer") }
        writer.startSession(atSourceTime: .zero)
        do {
            let deadline = Date().addingTimeInterval(30)
            for index in 0..<60 {
                while !input.isReadyForMoreMediaData {
                    guard writer.status == .writing, Date() < deadline else {
                        throw writer.error ?? FixtureError.failed("Fixture writer timed out")
                    }
                    try await Task.sleep(nanoseconds: 1_000_000)
                }
                var buffer: CVPixelBuffer?
                guard let pool = adaptor.pixelBufferPool,
                      CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
                      let buffer else { throw FixtureError.failed("Cannot allocate frame") }
                CVPixelBufferLockBaseAddress(buffer, [])
                let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
                let stride = CVPixelBufferGetBytesPerRow(buffer)
                for y in 0..<180 {
                    for x in 0..<320 {
                        let offset = y * stride + x * 4
                        base[offset] = UInt8((x + index * 3) % 256)
                        base[offset + 1] = UInt8(y)
                        base[offset + 2] = UInt8(index * 4)
                        base[offset + 3] = 255
                    }
                }
                CVPixelBufferUnlockBaseAddress(buffer, [])
                guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(index), timescale: 60)) else {
                    throw writer.error ?? FixtureError.failed("Cannot append frame")
                }
            }
            writer.endSession(atSourceTime: CMTime(value: 1, timescale: 1))
            input.markAsFinished()
            await writer.finishWriting()
            guard writer.status == .completed else {
                throw writer.error ?? FixtureError.failed("Fixture encoding failed")
            }
        } catch {
            writer.cancelWriting()
            throw error
        }

        let audioURL = folder.appendingPathComponent("tone.wav")
        try writeTone(to: audioURL)
        let videoAsset = AVURLAsset(url: silentURL)
        let audioAsset = AVURLAsset(url: audioURL)
        let composition = AVMutableComposition()
        let sourceVideos = try await videoAsset.loadTracks(withMediaType: .video)
        let sourceAudios = try await audioAsset.loadTracks(withMediaType: .audio)
        let sourceVideo = try XCTUnwrap(sourceVideos.first)
        let sourceAudio = try XCTUnwrap(sourceAudios.first)
        let videoTrack = try XCTUnwrap(composition.addMutableTrack(
            withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid
        ))
        let audioTrack = try XCTUnwrap(composition.addMutableTrack(
            withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid
        ))
        let range = CMTimeRange(start: .zero, duration: CMTime(value: 1, timescale: 1))
        try videoTrack.insertTimeRange(range, of: sourceVideo, at: .zero)
        videoTrack.preferredTransform = try await sourceVideo.load(.preferredTransform)
        try audioTrack.insertTimeRange(range, of: sourceAudio, at: .zero)
        let session = try XCTUnwrap(AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality))
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("qa-\(UUID().uuidString).mp4")
        session.outputURL = destination
        session.outputFileType = .mp4
        await session.export()
        guard session.status == .completed else {
            remove(destination)
            throw session.error ?? FixtureError.failed("Fixture audio mux failed")
        }
        return destination
    }

    private func writeTone(to url: URL) throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48_000))
        buffer.frameLength = 48_000
        let samples = try XCTUnwrap(buffer.floatChannelData)[0]
        for index in 0..<48_000 {
            samples[index] = Float(sin(Double(index) * 2 * Double.pi * 440 / 48_000) * 0.2)
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }

    private func assertAudioTiming(url: URL, file: StaticString = #filePath, line: UInt = #line) async throws {
        let asset = AVURLAsset(url: url)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audio = try XCTUnwrap(audioTracks.first, file: file, line: line)
        let video = try XCTUnwrap(videoTracks.first, file: file, line: line)
        let audioRange = try await audio.load(.timeRange)
        let videoRange = try await video.load(.timeRange)
        XCTAssertEqual(audioRange.start.seconds, videoRange.start.seconds, accuracy: 0.05, file: file, line: line)
        XCTAssertEqual(audioRange.end.seconds, videoRange.end.seconds, accuracy: 0.08, file: file, line: line)
    }

    private func decodedFrameCount(url: URL) async throws -> Int {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        guard reader.canAdd(output) else { throw FixtureError.failed("Cannot add decoder") }
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? FixtureError.failed("Cannot start decoder") }
        var count = 0
        var previous = -Double.infinity
        while let sample = output.copyNextSampleBuffer() {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            XCTAssertGreaterThan(timestamp, previous)
            XCTAssertNotNil(CMSampleBufferGetImageBuffer(sample))
            previous = timestamp
            count += 1
        }
        guard reader.status == .completed else {
            throw reader.error ?? FixtureError.failed("Decoding failed")
        }
        return count
    }

    private func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private enum FixtureError: Error {
        case failed(String)
    }
}
