import XCTest
@testable import Irfaali

final class VideoProcessingSettingsTests: XCTestCase {
    func test4KTargetPreservesPortraitAspectRatioAndEvenDimensions() {
        let info = fixture(width: 1080, height: 1920, fps: 60)
        let settings = VideoProcessingSettings(resolution: .ultraHD, frameRate: .fps60, codec: .hevc)

        let size = settings.targetSize(for: info)

        XCTAssertEqual(Int(size.height), 3840)
        XCTAssertEqual(Int(size.width), 2160)
        XCTAssertEqual(Int(size.width) % 2, 0)
        XCTAssertEqual(Int(size.height) % 2, 0)
    }

    func testDoesNotPretend30FPSSourceCanBecome60WithoutFrameGeneration() {
        let info = fixture(width: 1080, height: 1920, fps: 30)
        let settings = VideoProcessingSettings(resolution: .source, frameRate: .fps60, codec: .h264)

        XCTAssertTrue(settings.needsFrameGeneration(for: info))
        XCTAssertFalse(settings.canRunFrameRate(for: info))
        XCTAssertEqual(settings.effectiveFPS(for: info), 30, accuracy: 0.001)
    }

    func test60FPSSourceCanBeCappedTo30() {
        let info = fixture(width: 1920, height: 1080, fps: 60)
        let settings = VideoProcessingSettings(resolution: .source, frameRate: .fps30, codec: .h264)

        XCTAssertFalse(settings.needsFrameGeneration(for: info))
        XCTAssertEqual(settings.effectiveFPS(for: info), 30, accuracy: 0.001)
    }

    func testRecommendedSettingsNeverUpscaleSmallSource() {
        let info = fixture(width: 720, height: 1280, fps: 30)

        let settings = VideoProcessingSettings.recommended(for: info)

        XCTAssertEqual(settings.resolution, .source)
        XCTAssertEqual(settings.targetSize(for: info), CGSize(width: 720, height: 1280))
        XCTAssertEqual(
            VideoProcessingSettings.supportedResolutions(for: info),
            [.source, .fullHD, .qhd, .ultraHD]
        )
        XCTAssertEqual(
            VideoProcessingSettings.supportedFrameRates(for: info),
            [.source, .fps30, .fps60]
        )
    }

    func testEditorOffersResamplingAndImplementedTwoTimesGeneration() {
        let info = fixture(width: 1920, height: 1080, fps: 60)

        XCTAssertEqual(
            VideoProcessingSettings.supportedResolutions(for: info),
            [.source, .fullHD, .qhd, .ultraHD]
        )
        XCTAssertEqual(
            VideoProcessingSettings.supportedFrameRates(for: info),
            [.source, .fps30, .fps60, .fps120]
        )
    }

    func testPassThroughRequiresSourceResolutionFrameRateAndCodec() {
        let info = fixture(width: 1920, height: 1080, fps: 60)

        XCTAssertTrue(
            VideoProcessingSettings(resolution: .source, frameRate: .source, codec: .source)
                .isPassThrough(for: info)
        )
        XCTAssertFalse(
            VideoProcessingSettings(resolution: .fullHD, frameRate: .source, codec: .source)
                .isPassThrough(for: info)
        )
    }

    private func fixture(width: Int, height: Int, fps: Double) -> VideoAssetInfo {
        VideoAssetInfo(
            url: URL(fileURLWithPath: "/tmp/test.mp4"),
            fileName: "test.mp4",
            container: "mp4",
            duration: 10,
            fileSizeBytes: 1_000_000,
            width: width,
            height: height,
            sourceFPS: fps,
            estimatedBitrate: 8_000_000,
            videoCodec: "H.264 / AVC",
            dynamicRange: "SDR",
            audioCodec: "AAC",
            audioSampleRate: 48_000,
            audioChannels: 2,
            trackTimeScale: 60_000
        )
    }
}
