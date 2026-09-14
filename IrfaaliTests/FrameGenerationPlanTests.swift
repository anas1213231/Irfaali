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
        XCTAssertEqual(plan?.generatedFramesPerSourceGap, 2)
    }

    func testUnsupportedRatioIsRejectedInsteadOfFaked() {
        XCTAssertNotNil(FrameGenerationPlan.make(sourceFPS: 24, targetFPS: 60))
        XCTAssertNotNil(FrameGenerationPlan.make(sourceFPS: 30, targetFPS: 120))
    }

    func testTargetClockForCommonSources() throws {
        for source in [24.0, 25, 29.97, 30, 50, 59.94] {
            for target in [60.0, 120] where target > source + 0.5 {
                let plan = try XCTUnwrap(FrameGenerationPlan.make(sourceFPS: source, targetFPS: target))
                var next = 0
                var samples: [(time: Double, fraction: Double)] = []
                for i in 0..<Int(ceil(source)) {
                    samples += plan.samples(from: Double(i) / source, to: min(1, Double(i + 1) / source), nextIndex: &next)
                }
                XCTAssertEqual(samples.count, Int(target))
                for (index, sample) in samples.enumerated() {
                    XCTAssertEqual(sample.time, Double(index) / target, accuracy: 0.000001)
                    XCTAssertTrue((0...1).contains(sample.fraction))
                }
                XCTAssertTrue(samples.contains { $0.fraction > 0.01 && $0.fraction < 0.99 })
            }
        }
    }

    func testLowerTargetNeedsNoGeneration() {
        let plan = FrameGenerationPlan.make(sourceFPS: 60, targetFPS: 30)

        XCTAssertEqual(plan?.strategy, FrameGenerationPlan.Strategy.none)
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
