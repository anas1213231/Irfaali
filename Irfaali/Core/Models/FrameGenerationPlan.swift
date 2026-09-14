import Foundation

struct FrameGenerationPlan: Equatable, Sendable {
    enum Strategy: String, Sendable {
        case none
        case opticalFlow2x
    }

    let sourceFPS: Double
    let targetFPS: Double
    let strategy: Strategy
    let generatedFramesPerSourceGap: Int

    var needsGeneration: Bool { strategy != .none }

    static func make(sourceFPS: Double, targetFPS: Double) -> FrameGenerationPlan? {
        guard sourceFPS.isFinite, targetFPS.isFinite, sourceFPS > 0, targetFPS > 0 else { return nil }

        if targetFPS <= sourceFPS + 0.5 {
            return FrameGenerationPlan(
                sourceFPS: sourceFPS,
                targetFPS: min(targetFPS, sourceFPS),
                strategy: .none,
                generatedFramesPerSourceGap: 0
            )
        }

        let ratio = targetFPS / sourceFPS
        if ratio <= 8.01 && targetFPS <= 120 {
            return FrameGenerationPlan(
                sourceFPS: sourceFPS,
                targetFPS: targetFPS,
                strategy: .opticalFlow2x,
                generatedFramesPerSourceGap: max(1, Int(ceil(ratio)) - 1)
            )
        }

        return nil
    }

    /// Output timestamps are anchored to the target clock, including 24/25/29.97 sources.
    func samples(from start: Double, to end: Double, nextIndex: inout Int) -> [(time: Double, fraction: Double)] {
        guard end > start, start.isFinite, end.isFinite else { return [] }
        var result: [(time: Double, fraction: Double)] = []
        while Double(nextIndex) / targetFPS < end - 0.000001 {
            let time = Double(nextIndex) / targetFPS
            if time >= start - 0.000001 {
                result.append((time, min(1, max(0, (time - start) / (end - start)))))
            }
            nextIndex += 1
        }
        return result
    }

    func intermediateFractions() -> [Double] {
        guard generatedFramesPerSourceGap > 0 else { return [] }
        let divisor = Double(generatedFramesPerSourceGap + 1)
        return (1...generatedFramesPerSourceGap).map { Double($0) / divisor }
    }
}
