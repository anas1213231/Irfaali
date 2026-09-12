import XCTest
@testable import Irfaali

final class FrameRateClassifierTests: XCTestCase {
    func testPreservedThirtyFPSIsNativeOutput() {
        let result = FrameRateClassifier.classify(sourceFPS: 30, outputFPS: 30, mode: .preserved)
        XCTAssertEqual(result.title, "Native Output 30 FPS")
        XCTAssertEqual(result.detail, "Source cadence preserved")
    }

    func testDuplicatedFPSIsNeverNative() {
        let result = FrameRateClassifier.classify(sourceFPS: 60, outputFPS: 120, mode: .duplicated)
        XCTAssertEqual(result.title, "Generated 120 FPS")
        XCTAssertEqual(result.detail, "Frame Duplication")
    }

    func testContainerTimingDoesNotClaimFrames() {
        let result = FrameRateClassifier.classify(sourceFPS: 60, outputFPS: 120, mode: .containerTimingOnly)
        XCTAssertEqual(result.title, "Container Timing Experiment")
    }

    func testRetimingIsExplicit() {
        let result = FrameRateClassifier.classify(sourceFPS: 120, outputFPS: 60, mode: .retimed)
        XCTAssertEqual(result.title, "Retimed 60 FPS")
    }
}
