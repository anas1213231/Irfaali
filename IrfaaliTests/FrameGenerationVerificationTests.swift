import XCTest
@testable import Irfaali

final class FrameGenerationVerificationTests: XCTestCase {
    func testPassesComplete30To60Generation() {
        let result = FrameGenerationVerification.verify2x(
            sourceFrameCount: 301,
            generatedFrameCount: 300,
            expectedFPS: 60,
            actualFPS: 59.94
        )

        XCTAssertTrue(result.passed)
        XCTAssertEqual(result.status, .passed)
    }

    func testRejectsUnchangedSourceCadence() {
        let result = FrameGenerationVerification.verify2x(
            sourceFrameCount: 301,
            generatedFrameCount: 300,
            expectedFPS: 60,
            actualFPS: 30
        )

        XCTAssertFalse(result.passed)
    }

    func testRejectsMissingGeneratedFrames() {
        let result = FrameGenerationVerification.verify2x(
            sourceFrameCount: 120,
            generatedFrameCount: 0,
            expectedFPS: 120,
            actualFPS: 120
        )

        XCTAssertFalse(result.passed)
        guard case .failed(let failures) = result.status else {
            return XCTFail("Expected verification failure")
        }
        XCTAssertTrue(failures.contains(.noGeneratedFrames))
    }

    func testAllowsSmallTailDecodeToleranceOnLongClips() {
        let result = FrameGenerationVerification.verify2x(
            sourceFrameCount: 100,
            generatedFrameCount: 97,
            expectedFPS: 60,
            actualFPS: 60
        )

        XCTAssertTrue(result.passed)
    }

    func testShortClipRequiresEveryMidpoint() {
        let result = FrameGenerationVerification.verify2x(
            sourceFrameCount: 8,
            generatedFrameCount: 6,
            expectedFPS: 60,
            actualFPS: 60
        )

        XCTAssertFalse(result.passed)
    }
}
