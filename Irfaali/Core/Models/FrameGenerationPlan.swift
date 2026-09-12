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
        if abs(ratio - 2.0) <= 0.04 {
            return FrameGenerationPlan(
                sourceFPS: sourceFPS,
                targetFPS: targetFPS,
                strategy: .opticalFlow2x,
                generatedFramesPerSourceGap: 1
            )
        }

        return nil
    }

    func intermediateFractions() -> [Double] {
        guard generatedFramesPerSourceGap > 0 else { return [] }
        let divisor = Double(generatedFramesPerSourceGap + 1)
        return (1...generatedFramesPerSourceGap).map { Double($0) / divisor }
    }
}
