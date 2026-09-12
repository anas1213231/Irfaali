import XCTest
@testable import Irfaali

final class VideoEnhancementSettingsTests: XCTestCase {
    func testSmartProfileEnablesRealEnhancementControls() {
        let info = fixture(width: 1080, height: 1920, fps: 30, bitrate: 3_000_000)
        let profile = VideoEnhancementSettings.smart(for: info)

        XCTAssertEqual(profile.mode, .smart)
        XCTAssertTrue(profile.isEnabled)
        XCTAssertGreaterThan(profile.denoise, 0)
        XCTAssertGreaterThan(profile.detailRecovery, 0)
        XCTAssertGreaterThan(profile.sharpening, 0)
    }

    func testLowBitrateGetsMoreDenoiseThanHighBitrate() {
        let low = VideoEnhancementSettings.smart(
            for: fixture(width: 1080, height: 1920, fps: 30, bitrate: 2_000_000)
        )
        let high = VideoEnhancementSettings.smart(
            for: fixture(width: 1080, height: 1920, fps: 30, bitrate: 18_000_000)
        )

        XCTAssertGreaterThan(low.denoise, high.denoise)
    }

    func testPresetOffDisablesEnhancement() {
        let info = fixture(width: 2160, height: 3840, fps: 60, bitrate: 30_000_000)
        let profile = VideoEnhancementSettings.preset(.off, info: info)

        XCTAssertEqual(profile.mode, .off)
        XCTAssertFalse(profile.isEnabled)
    }

    func testNormalizedClampsManualValues() {
        let profile = VideoEnhancementSettings(
            mode: .custom,
            denoise: 2,
            detailRecovery: -1,
            sharpening: 1.5,
            colorBoost: 0.5
        ).normalized()

        XCTAssertEqual(profile.denoise, 1, accuracy: 0.0001)
        XCTAssertEqual(profile.detailRecovery, 0, accuracy: 0.0001)
        XCTAssertEqual(profile.sharpening, 1, accuracy: 0.0001)
        XCTAssertEqual(profile.colorBoost, 0.5, accuracy: 0.0001)
    }

    private func fixture(
        width: Int,
        height: Int,
        fps: Double,
        bitrate: Double
    ) -> VideoAssetInfo {
        VideoAssetInfo(
            url: URL(fileURLWithPath: "/tmp/test.mp4"),
            fileName: "test.mp4",
            container: "MP4",
            duration: 10,
            fileSizeBytes: 1_000_000,
            width: width,
            height: height,
            sourceFPS: fps,
            estimatedBitrate: bitrate,
            videoCodec: "H.264 / AVC",
            dynamicRange: "SDR",
            audioCodec: "AAC",
            audioSampleRate: 48_000,
            audioChannels: 2,
            trackTimeScale: 60_000
        )
    }
}
