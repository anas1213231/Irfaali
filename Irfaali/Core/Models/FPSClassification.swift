import Foundation

enum FPSGenerationMode: Equatable, Sendable {
    case preserved
    case duplicated
    case interpolated
    case retimed
    case containerTimingOnly
}

struct FPSClassification: Equatable, Sendable {
    let title: String
    let detail: String
}

enum FrameRateClassifier {
    static func classify(sourceFPS: Double, outputFPS: Double, mode: FPSGenerationMode) -> FPSClassification {
        switch mode {
        case .preserved:
            return FPSClassification(
                title: "Native Output \(format(outputFPS)) FPS",
                detail: approximatelyEqual(sourceFPS, outputFPS) ? "Source cadence preserved" : "Output cadence reported by encoder"
            )
        case .duplicated:
            return FPSClassification(title: "Generated \(format(outputFPS)) FPS", detail: "Frame Duplication")
        case .interpolated:
            return FPSClassification(title: "Generated \(format(outputFPS)) FPS", detail: "Interpolated")
        case .retimed:
            return FPSClassification(title: "Retimed \(format(outputFPS)) FPS", detail: "Cadence conversion — not native capture")
        case .containerTimingOnly:
            return FPSClassification(title: "Container Timing Experiment", detail: "Timing metadata changed; frames were not created")
        }
    }

    private static func approximatelyEqual(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.01
    }

    private static func format(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.01 { return String(Int(value.rounded())) }
        return String(format: "%.2f", value)
    }
}
