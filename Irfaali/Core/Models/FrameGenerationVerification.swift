import Foundation

struct FrameGenerationVerification: Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case passed
        case failed([Failure])
    }

    enum Failure: Equatable, Sendable, CustomStringConvertible {
        case noIntermediateFrames
        case insufficientIntermediateFrames(expectedMinimum: Int, actual: Int)
        case outputFPSMismatch(expected: Double, actual: Double)

        var description: String {
            switch self {
            case .noIntermediateFrames:
                return "No synthesized or cut-safe cadence frames were produced."
            case .insufficientIntermediateFrames(let expectedMinimum, let actual):
                return "Expected at least \(expectedMinimum) intermediate cadence frames, got \(actual)."
            case .outputFPSMismatch(let expected, let actual):
                return String(format: "Expected %.3f FPS, analyzer reported %.3f FPS.", expected, actual)
            }
        }
    }

    let sourceFrameCount: Int
    let generatedFrameCount: Int
    let sceneCutFallbackFrameCount: Int
    let expectedFPS: Double
    let actualFPS: Double
    let status: Status

    var passed: Bool {
        if case .passed = status { return true }
        return false
    }

    var totalIntermediateFrameCount: Int {
        generatedFrameCount + sceneCutFallbackFrameCount
    }

    static func verify2x(
        sourceFrameCount: Int,
        generatedFrameCount: Int,
        sceneCutFallbackFrameCount: Int = 0,
        expectedFPS: Double,
        actualFPS: Double
    ) -> FrameGenerationVerification {
        var failures: [Failure] = []
        let totalIntermediate = generatedFrameCount + sceneCutFallbackFrameCount

        if sourceFrameCount > 1, totalIntermediate <= 0 {
            failures.append(.noIntermediateFrames)
        }

        // With N decoded source frames, a complete 2× run produces N-1 midpoint
        // cadence samples. Most gaps must be genuine motion synthesis. A hard edit is
        // the deliberate exception: the scene-cut detector inserts a separately
        // counted temporal hold to avoid cross-shot ghosting and never reports that
        // hold as an AI-generated frame.
        let expectedMidpoints = max(sourceFrameCount - 1, 0)
        let toleratedMissingTail = sourceFrameCount >= 20 ? 2 : 0
        let minimumIntermediate = max(expectedMidpoints - toleratedMissingTail, 0)
        if totalIntermediate < minimumIntermediate {
            failures.append(
                .insufficientIntermediateFrames(
                    expectedMinimum: minimumIntermediate,
                    actual: totalIntermediate
                )
            )
        }

        // Encoders/analyzers often report 59.94 for a nominal 60 and 119.88 for
        // nominal 120. A 0.35 FPS absolute tolerance keeps that legitimate cadence
        // while rejecting an unchanged 30/60 FPS file.
        if !expectedFPS.isFinite || !actualFPS.isFinite || abs(expectedFPS - actualFPS) > 0.35 {
            failures.append(.outputFPSMismatch(expected: expectedFPS, actual: actualFPS))
        }

        return FrameGenerationVerification(
            sourceFrameCount: sourceFrameCount,
            generatedFrameCount: generatedFrameCount,
            sceneCutFallbackFrameCount: sceneCutFallbackFrameCount,
            expectedFPS: expectedFPS,
            actualFPS: actualFPS,
            status: failures.isEmpty ? .passed : .failed(failures)
        )
    }
}
