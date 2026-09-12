import XCTest
@testable import Irfaali

final class FrameGenerationPlanTests: XCTestCase {
    func test30To60UsesRealOpticalFlow2xPlan() {
        let plan = FrameGenerationPlan.make(sourceFPS: 30, targetFPS: 60)

        XCTAssertEqual(plan?.strategy, .opticalFlow2x)
        XCTAssertEqual(plan?.generatedFramesPerSourceGap, 1)
        XCTAssertEqual(plan?.intermediateFractions(), [0.5])
    }

    func test5994To120AcceptsNormalCadenceTolerance() {
        let plan = FrameGenerationPlan.make(sourceFPS: 59.94, targetFPS: 120)

        XCTAssertEqual(plan?.strategy, .opticalFlow2x)
        XCTAssertEqual(plan?.generatedFramesPerSourceGap, 1)
    }

    func testUnsupportedRatioIsRejectedInsteadOfFaked() {
        XCTAssertNil(FrameGenerationPlan.make(sourceFPS: 24, targetFPS: 60))
        XCTAssertNil(FrameGenerationPlan.make(sourceFPS: 30, targetFPS: 120))
    }

    func testLowerTargetNeedsNoGeneration() {
        let plan = FrameGenerationPlan.make(sourceFPS: 60, targetFPS: 30)

        XCTAssertEqual(plan?.strategy, .none)
        XCTAssertEqual(plan?.generatedFramesPerSourceGap, 0)
        XCTAssertEqual(plan?.targetFPS, 30)
    }

    func testInvalidRatesAreRejected() {
        XCTAssertNil(FrameGenerationPlan.make(sourceFPS: 0, targetFPS: 60))
        XCTAssertNil(FrameGenerationPlan.make(sourceFPS: 30, targetFPS: .infinity))
        XCTAssertNil(FrameGenerationPlan.make(sourceFPS: .nan, targetFPS: 60))
    }

    func testInterpolatedClassificationNamesGeneratedOutputHonestly() {
        let classification = FrameRateClassifier.classify(
            sourceFPS: 30,
            outputFPS: 60,
            mode: .interpolated
        )

        XCTAssertEqual(classification.title, "Generated 60 FPS")
        XCTAssertEqual(classification.detail, "Interpolated")
    }
}
