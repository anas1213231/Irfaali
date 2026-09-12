import XCTest
@testable import Irfaali

final class FrameGenerationPlanTests: XCTestCase {
    func test30To60UsesSingleOpticalFlowFramePerGap() {
        let plan = FrameGenerationPlan.make(sourceFPS: 30, targetFPS: 60)

        XCTAssertEqual(plan?.strategy, .opticalFlow2x)
        XCTAssertEqual(plan?.generatedFramesPerSourceGap, 1)
        XCTAssertEqual(plan?.intermediateFractions(), [0.5])
    }

    func test60To120UsesSameTwoXStrategy() {
        let plan = FrameGenerationPlan.make(sourceFPS: 60, targetFPS: 120)

        XCTAssertEqual(plan?.strategy, .opticalFlow2x)
        XCTAssertEqual(plan?.intermediateFractions(), [0.5])
    }

    func testUnsupportedRatioIsRejectedInsteadOfFaked() {
        XCTAssertNil(FrameGenerationPlan.make(sourceFPS: 24, targetFPS: 60))
    }

    func testLowerTargetNeedsNoGeneration() {
        let plan = FrameGenerationPlan.make(sourceFPS: 60, targetFPS: 30)

        XCTAssertEqual(plan?.strategy, .none)
        XCTAssertFalse(plan?.needsGeneration ?? true)
    }
}
