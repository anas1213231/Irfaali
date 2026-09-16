import XCTest
@testable import Irfaali

final class VideoRecommendationTests: XCTestCase {
    func testClean60FPSVideoStaysConservative() {
        let info = makeInfo(width: 1920, height: 1080, fps: 60)
        let report = VideoAnalysisReport(
            sampledFrameCount: 5,
            averageLuminance: 0.50,
            luminanceDeviation: 0.22,
            highlightClippingRatio: 0.01,
            shadowClippingRatio: 0.02,
            sharpnessScore: 0.62,
            noiseScore: 0.04,
            compressionArtifactScore: 0.04,
            saturationScore: 0.34,
            colorCastScore: 0.06,
            motionScore: 0.18,
            sceneChangeCount: 0
        )

        let recommendation = VideoRecommendationEngine.recommend(info: info, report: report)

        XCTAssertEqual(recommendation.processing.resolution, .source)
        XCTAssertEqual(recommendation.processing.frameRate, .fps60)
        XCTAssertFalse(recommendation.enhancement.isEnabled)
    }

    func testLowLightNoisy30FPSVideoGetsRestrainedTreatmentAnd60FPSMotionRecommendation() {
        let info = makeInfo(width: 1920, height: 1080, fps: 30)
        let report = VideoAnalysisReport(
            sampledFrameCount: 5,
            averageLuminance: 0.21,
            luminanceDeviation: 0.11,
            highlightClippingRatio: 0.005,
            shadowClippingRatio: 0.20,
            sharpnessScore: 0.24,
            noiseScore: 0.46,
            compressionArtifactScore: 0.18,
            saturationScore: 0.20,
            colorCastScore: 0.12,
            motionScore: 0.17,
            sceneChangeCount: 0
        )

        let recommendation = VideoRecommendationEngine.recommend(info: info, report: report)

        XCTAssertEqual(recommendation.processing.frameRate, .fps60)
        XCTAssertGreaterThan(recommendation.enhancement.denoise, 0)
        XCTAssertGreaterThan(recommendation.enhancement.exposure, 0)
        XCTAssertLessThanOrEqual(recommendation.enhancement.exposure, 0.16)
        XCTAssertLessThanOrEqual(recommendation.enhancement.sharpening, 0.16)
    }

    func testHighlightLimitedVideoNeverGetsPositiveExposure() {
        let info = makeInfo(width: 3840, height: 2160, fps: 30)
        let report = VideoAnalysisReport(
            sampledFrameCount: 7,
            averageLuminance: 0.78,
            luminanceDeviation: 0.20,
            highlightClippingRatio: 0.12,
            shadowClippingRatio: 0.01,
            sharpnessScore: 0.50,
            noiseScore: 0.08,
            compressionArtifactScore: 0.08,
            saturationScore: 0.30,
            colorCastScore: 0.08,
            motionScore: 0.05,
            sceneChangeCount: 1
        )

        let recommendation = VideoRecommendationEngine.recommend(info: info, report: report)

        XCTAssertLessThanOrEqual(recommendation.enhancement.exposure, 0)
        XCTAssertNotEqual(recommendation.processing.frameRate, .fps120)
    }

    func testRecommendationNeverAutomaticallyTargets120FPS() {
        let info = makeInfo(width: 1920, height: 1080, fps: 24)
        let report = VideoAnalysisReport(
            sampledFrameCount: 7,
            averageLuminance: 0.48,
            luminanceDeviation: 0.20,
            highlightClippingRatio: 0.01,
            shadowClippingRatio: 0.02,
            sharpnessScore: 0.46,
            noiseScore: 0.08,
            compressionArtifactScore: 0.08,
            saturationScore: 0.32,
            colorCastScore: 0.05,
            motionScore: 0.40,
            sceneChangeCount: 0
        )

        let recommendation = VideoRecommendationEngine.recommend(info: info, report: report)

        XCTAssertEqual(recommendation.processing.frameRate, .fps60)
        XCTAssertNotEqual(recommendation.processing.frameRate, .fps120)
    }

    private func makeInfo(width: Int, height: Int, fps: Double) -> VideoAssetInfo {
        VideoAssetInfo(
            url: URL(fileURLWithPath: "/tmp/recommendation-test.mov"),
            fileName: "recommendation-test.mov",
            container: "MOV",
            duration: 10,
            fileSizeBytes: 20_000_000,
            width: width,
            height: height,
            sourceFPS: fps,
            estimatedBitrate: 12_000_000,
            videoCodec: "H.264 / AVC",
            dynamicRange: "SDR",
            audioCodec: "AAC",
            audioSampleRate: 48_000,
            audioChannels: 2,
            trackTimeScale: 60_000
        )
    }
}
