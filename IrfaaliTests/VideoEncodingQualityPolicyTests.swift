import CoreGraphics
import XCTest
@testable import Irfaali

final class VideoEncodingQualityPolicyTests: XCTestCase {
    func test1080p60H264KeepsHighQualityBudget() {
        let bitrate = VideoEncodingQualityPolicy.targetBitrate(
            size: CGSize(width: 1920, height: 1080),
            fps: 60,
            hevc: false,
            sourceBitrate: 8_000_000
        )

        XCTAssertGreaterThanOrEqual(bitrate, 19_000_000)
        XCTAssertLessThanOrEqual(bitrate, 140_000_000)
    }

    func test1080p60HEVCUsesEfficientButStrongBudget() {
        let bitrate = VideoEncodingQualityPolicy.targetBitrate(
            size: CGSize(width: 1920, height: 1080),
            fps: 60,
            hevc: true,
            sourceBitrate: 8_000_000
        )

        XCTAssertGreaterThanOrEqual(bitrate, 12_000_000)
        XCTAssertLessThan(bitrate, 20_000_000)
    }

    func testHealthySourceBitrateIsNotNeedlesslyReduced() {
        let bitrate = VideoEncodingQualityPolicy.targetBitrate(
            size: CGSize(width: 1280, height: 720),
            fps: 30,
            hevc: false,
            sourceBitrate: 24_000_000
        )

        XCTAssertEqual(bitrate, 24_000_000)
    }

    func testPathologicalSourceBitrateIsCapped() {
        let bitrate = VideoEncodingQualityPolicy.targetBitrate(
            size: CGSize(width: 3840, height: 2160),
            fps: 120,
            hevc: false,
            sourceBitrate: 900_000_000
        )

        XCTAssertEqual(bitrate, 140_000_000)
    }
}
