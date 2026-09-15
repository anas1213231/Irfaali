import Foundation

/// Validate encoded output rather than displaying the requested settings as facts.
enum OutputVerification {
    static func mismatch(source: VideoAssetInfo, output: VideoAssetInfo, settings: VideoProcessingSettings) -> String? {
        let size = settings.targetSize(for: source)
        if output.width != Int(size.width) || output.height != Int(size.height) {
            return "Expected \(Int(size.width))×\(Int(size.height)); received \(output.width)×\(output.height)."
        }
        let targetFPS = settings.frameRate.requestedFPS ?? source.sourceFPS
        let expectedFPS = settings.needsFrameGeneration(for: source) ? targetFPS : settings.effectiveFPS(for: source)
        if !output.sourceFPS.isFinite || output.sourceFPS <= 0 || abs(output.sourceFPS - expectedFPS) > 0.5 {
            return String(format: "Expected %.3f FPS; received %.3f FPS.", expectedFPS, output.sourceFPS)
        }
        if !output.duration.isFinite || output.duration <= 0 || abs(output.duration - source.duration) > max(0.15, 2 / max(source.sourceFPS, 1)) {
            return "Output duration does not match the source."
        }
        if source.audioCodec != nil && output.audioCodec == nil {
            return "The source audio is missing from the output."
        }
        if output.fileSizeBytes <= 0 { return "The output file is empty." }
        switch settings.codec {
        case .h264:
            if !output.videoCodec.contains("H.264") { return "The output codec is not H.264." }
        case .hevc:
            if !output.videoCodec.contains("HEVC") { return "The output codec is not HEVC." }
        case .source: break
        }
        return nil
    }
}
