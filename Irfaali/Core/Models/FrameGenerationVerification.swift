import Foundation

struct FrameGenerationVerification: Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case passed
        case failed([Failure])
    }

    enum Failure: Equatable, Sendable, CustomStringConvertible {
        case noGeneratedFrames
        case insufficientGeneratedFrames(expectedMinimum: Int, actual: Int)
        case outputFPSMismatch(expected: Double, actual: Double)

        var description: String {
            switch self {
            case .noGeneratedFrames:
                return "No synthesized frames were produced."
            case .insufficientGeneratedFrames(let expectedMinimum, let actual):
                return "Expected at least \(expectedMinimum) synthesized frames, got \(actual)."
            case .outputFPSMismatch(let expected, let actual):
                return String(format: "Expected %.3f FPS, analyzer reported %.3f FPS.", expected, actual)
            }
        }
    }

    let sourceFrameCount: Int
    let generatedFrameCount: Int
    let expectedFPS: Double
    let actualFPS: Double
    let status: Status

    var passed: Bool {
        if case .passed = status { return true }
        return false
    }

    static func verify2x(
        sourceFrameCount: Int,
        generatedFrameCount: Int,
        expectedFPS: Double,
        actualFPS: Double
    ) -> FrameGenerationVerification {
        var failures: [Failure] = []

        if generatedFrameCount <= 0 {
            failures.append(.noGeneratedFrames)
        }

        // With N decoded source frames, a complete 2× run can synthesize N-1
        // midpoint frames. Allow a tiny tail tolerance for sources whose final
        // decode sample is intentionally dropped by the decoder/container.
        let expectedMidpoints = max(sourceFrameCount - 1, 0)
        let toleratedMissingTail = sourceFrameCount >= 20 ? 2 : 0
        let minimumGenerated = max(expectedMidpoints - toleratedMissingTail, 0)
        if generatedFrameCount < minimumGenerated {
            failures.append(
                .insufficientGeneratedFrames(
                    expectedMinimum: minimumGenerated,
                    actual: generatedFrameCount
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
            expectedFPS: expectedFPS,
            actualFPS: actualFPS,
            status: failures.isEmpty ? .passed : .failed(failures)
        )
    }
}
