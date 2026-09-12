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
        XCTAssertEqual(result.sceneCutFallbackFrameCount, 0)
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

    func testRejectsMissingIntermediateFrames() {
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
        XCTAssertTrue(failures.contains(.noIntermediateFrames))
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

    func testSceneCutFallbackCountsForCadenceButNotAsGeneratedFrame() {
        let result = FrameGenerationVerification.verify2x(
            sourceFrameCount: 101,
            generatedFrameCount: 94,
            sceneCutFallbackFrameCount: 6,
            expectedFPS: 60,
            actualFPS: 59.94
        )

        XCTAssertTrue(result.passed)
        XCTAssertEqual(result.generatedFrameCount, 94)
        XCTAssertEqual(result.sceneCutFallbackFrameCount, 6)
        XCTAssertEqual(result.totalIntermediateFrameCount, 100)
    }
}
