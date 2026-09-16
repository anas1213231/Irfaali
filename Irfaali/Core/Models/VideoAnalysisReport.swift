import Foundation

struct VideoAnalysisReport: Equatable, Sendable {
    enum MotionLevel: String, Sendable {
        case low
        case medium
        case high
    }

    let sampledFrameCount: Int
    let averageLuminance: Double
    let luminanceDeviation: Double
    let highlightClippingRatio: Double
    let shadowClippingRatio: Double
    let sharpnessScore: Double
    let noiseScore: Double
    let compressionArtifactScore: Double
    let saturationScore: Double
    let colorCastScore: Double
    let motionScore: Double
    let sceneChangeCount: Int

    var motionLevel: MotionLevel {
        switch motionScore {
        case ..<0.10:
            return .low
        case ..<0.24:
            return .medium
        default:
            return .high
        }
    }

    var isLowLight: Bool {
        averageLuminance < 0.30 || shadowClippingRatio > 0.16
    }

    var isHighlightLimited: Bool {
        highlightClippingRatio > 0.045
    }

    var isSoft: Bool {
        sharpnessScore < 0.30
    }

    var isNoisy: Bool {
        noiseScore > 0.24
    }

    var isCompressionStressed: Bool {
        compressionArtifactScore > 0.26
    }

    static let metadataOnlyFallback = VideoAnalysisReport(
        sampledFrameCount: 0,
        averageLuminance: 0.50,
        luminanceDeviation: 0.18,
        highlightClippingRatio: 0,
        shadowClippingRatio: 0,
        sharpnessScore: 0.50,
        noiseScore: 0,
        compressionArtifactScore: 0,
        saturationScore: 0.35,
        colorCastScore: 0,
        motionScore: 0,
        sceneChangeCount: 0
    )
}
