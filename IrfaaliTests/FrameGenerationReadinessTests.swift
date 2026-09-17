import XCTest
@testable import Irfaali

final class FrameGenerationReadinessTests: XCTestCase {
    func testReadyForHealthyMetalDeviceAnd1080p2xPlan() {
        let readiness = FrameGenerationReadiness.evaluate(
            plan: FrameGenerationPlan.make(sourceFPS: 30, targetFPS: 60),
            width: 1920,
            height: 1080,
            environment: .init(
                metalAvailable: true,
                isSimulator: false,
                lowPowerModeEnabled: false,
                thermalLevel: .nominal
            )
        )

        XCTAssertEqual(readiness.level, .ready)
        XCTAssertTrue(readiness.canStart)
        XCTAssertTrue(readiness.reasons.isEmpty)
    }

    func testLowPowerModeProducesCautionInsteadOfFakeFailure() {
        let readiness = FrameGenerationReadiness.evaluate(
            plan: FrameGenerationPlan.make(sourceFPS: 30, targetFPS: 60),
            width: 1920,
            height: 1080,
            environment: .init(
                metalAvailable: true,
                isSimulator: false,
                lowPowerModeEnabled: true,
                thermalLevel: .fair
            )
        )

        XCTAssertEqual(readiness.level, .caution)
        XCTAssertTrue(readiness.canStart)
        XCTAssertTrue(readiness.reasons.contains(.lowPowerMode))
    }

    func testCriticalThermalStateBlocksGeneration() {
        let readiness = FrameGenerationReadiness.evaluate(
            plan: FrameGenerationPlan.make(sourceFPS: 60, targetFPS: 120),
            width: 2560,
            height: 1440,
            environment: .init(
                metalAvailable: true,
                isSimulator: false,
                lowPowerModeEnabled: false,
                thermalLevel: .critical
            )
        )

        XCTAssertEqual(readiness.level, .blocked)
        XCTAssertFalse(readiness.canStart)
        XCTAssertTrue(readiness.reasons.contains(.thermalCritical))
    }

    func testRuntimeThermalGuardStopsCriticalImmediately() {
        var guardState = FrameGenerationReadiness.RuntimeThermalGuard()

        XCTAssertEqual(
            guardState.evaluate(level: .critical, uptime: 100),
            .stop(.critical)
        )
    }

    func testRuntimeThermalGuardAllowsTransientSeriousPressure() {
        var guardState = FrameGenerationReadiness.RuntimeThermalGuard()

        XCTAssertEqual(
            guardState.evaluate(level: .serious, uptime: 100),
            .continueProcessing
        )
        XCTAssertEqual(
            guardState.evaluate(
                level: .serious,
                uptime: 100 + FrameGenerationReadiness.RuntimeThermalGuard.seriousGracePeriod - 0.01
            ),
            .continueProcessing
        )
    }

    func testRuntimeThermalGuardStopsPersistentSeriousPressure() {
        var guardState = FrameGenerationReadiness.RuntimeThermalGuard()
        _ = guardState.evaluate(level: .serious, uptime: 100)

        XCTAssertEqual(
            guardState.evaluate(
                level: .serious,
                uptime: 100 + FrameGenerationReadiness.RuntimeThermalGuard.seriousGracePeriod
            ),
            .stop(.serious)
        )
    }

    func testRuntimeThermalGuardResetsAfterThermalRecovery() {
        var guardState = FrameGenerationReadiness.RuntimeThermalGuard()
        _ = guardState.evaluate(level: .serious, uptime: 100)
        _ = guardState.evaluate(level: .fair, uptime: 103)

        XCTAssertEqual(
            guardState.evaluate(level: .serious, uptime: 106),
            .continueProcessing
        )
        XCTAssertEqual(
            guardState.evaluate(level: .serious, uptime: 109),
            .continueProcessing
        )
    }

    func testMissingMetalBlocksGeneration() {
        let readiness = FrameGenerationReadiness.evaluate(
            plan: FrameGenerationPlan.make(sourceFPS: 30, targetFPS: 60),
            width: 1920,
            height: 1080,
            environment: .init(
                metalAvailable: false,
                isSimulator: false,
                lowPowerModeEnabled: false,
                thermalLevel: .nominal
            )
        )

        XCTAssertEqual(readiness.level, .blocked)
        XCTAssertTrue(readiness.reasons.contains(.metalUnavailable))
    }

    func testOversized8KFrameMustBeDownscaledBeforeGeneration() {
        let readiness = FrameGenerationReadiness.evaluate(
            plan: FrameGenerationPlan.make(sourceFPS: 30, targetFPS: 60),
            width: 7680,
            height: 4320,
            environment: .init(
                metalAvailable: true,
                isSimulator: false,
                lowPowerModeEnabled: false,
                thermalLevel: .nominal
            )
        )

        XCTAssertEqual(readiness.level, .blocked)
        XCTAssertFalse(readiness.canStart)
        XCTAssertTrue(
            readiness.reasons.contains(.oversizedFrame(width: 7680, height: 4320))
        )
    }

    func testUnsupportedRatioIsBlocked() {
        let readiness = FrameGenerationReadiness.evaluate(
            plan: FrameGenerationPlan.make(sourceFPS: 10, targetFPS: 120),
            width: 1920,
            height: 1080,
            environment: .init(
                metalAvailable: true,
                isSimulator: false,
                lowPowerModeEnabled: false,
                thermalLevel: .nominal
            )
        )

        XCTAssertEqual(readiness.level, .blocked)
        XCTAssertEqual(readiness.reasons, [.unsupportedPlan])
    }

    #if targetEnvironment(simulator)
    func testCurrentEnvironmentIsSafeAndExplicitOnSimulator() {
        let environment = FrameGenerationReadiness.Environment.current()

        XCTAssertTrue(environment.isSimulator)
        XCTAssertFalse(environment.lowPowerModeEnabled)
        XCTAssertEqual(environment.thermalLevel, .nominal)
        XCTAssertEqual(FrameGenerationReadiness.currentThermalLevel(), .nominal)
    }
    #endif
}
