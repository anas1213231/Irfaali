import CoreGraphics
import Foundation

struct VideoProcessingSettings: Equatable, Sendable {
    enum Resolution: String, CaseIterable, Identifiable, Sendable {
        case source
        case fullHD
        case qhd
        case ultraHD

        var id: String { rawValue }

        var maximumLongEdge: CGFloat? {
            switch self {
            case .source: nil
            case .fullHD: 1920
            case .qhd: 2560
            case .ultraHD: 3840
            }
        }

        func title(isArabic: Bool) -> String {
            switch self {
            case .source: isArabic ? "نفس الدقة" : "Source"
            case .fullHD: "1080p"
            case .qhd: "2K"
            case .ultraHD: "4K"
            }
        }
    }

    enum FrameRate: String, CaseIterable, Identifiable, Sendable {
        case source
        case fps30
        case fps60
        case fps120

        var id: String { rawValue }

        var requestedFPS: Double? {
            switch self {
            case .source: nil
            case .fps30: 30
            case .fps60: 60
            case .fps120: 120
            }
        }

        func title(isArabic: Bool) -> String {
            switch self {
            case .source: isArabic ? "نفس الفريمات" : "Source"
            case .fps30: "30 FPS"
            case .fps60: "60 FPS"
            case .fps120: "120 FPS"
            }
        }
    }

    enum Codec: String, CaseIterable, Identifiable, Sendable {
        case source
        case h264
        case hevc

        var id: String { rawValue }

        func title(isArabic: Bool) -> String {
            switch self {
            case .source: isArabic ? "نفس الترميز" : "Source"
            case .h264: "H.264"
            case .hevc: "H.265 / HEVC"
            }
        }
    }

    var resolution: Resolution = .source
    var frameRate: FrameRate = .source
    var codec: Codec = .h264

    static let standard = VideoProcessingSettings()

    static func recommended(for info: VideoAssetInfo) -> VideoProcessingSettings {
        let resolution: Resolution
        let sourceLongEdge = max(info.width, info.height)
        if sourceLongEdge >= 3840 {
            resolution = .source
        } else if sourceLongEdge >= 2560 {
            resolution = .qhd
        } else if sourceLongEdge >= 1920 {
            resolution = .fullHD
        } else {
            // Never upscale by default. A smaller source should stay at its
            // native dimensions until the user explicitly chooses otherwise.
            resolution = .source
        }

        let frameRate: FrameRate = info.sourceFPS >= 59.5 ? .fps60 : .source
        let codec: Codec = info.videoCodec.localizedCaseInsensitiveContains("HEVC") || info.videoCodec.localizedCaseInsensitiveContains("H.265") ? .hevc : .h264

        return VideoProcessingSettings(
            resolution: resolution,
            frameRate: frameRate,
            codec: codec
        )
    }

    func targetSize(for info: VideoAssetInfo) -> CGSize {
        guard let maximumLongEdge = resolution.maximumLongEdge else {
            return evenSize(width: CGFloat(info.width), height: CGFloat(info.height))
        }

        let sourceWidth = CGFloat(max(info.width, 1))
        let sourceHeight = CGFloat(max(info.height, 1))
        let sourceLongEdge = max(sourceWidth, sourceHeight)
        let scale = maximumLongEdge / sourceLongEdge

        return evenSize(
            width: sourceWidth * scale,
            height: sourceHeight * scale
        )
    }

    func effectiveFPS(for info: VideoAssetInfo) -> Double {
        guard let requested = frameRate.requestedFPS else { return info.sourceFPS }
        return min(requested, info.sourceFPS)
    }

    func needsFrameGeneration(for info: VideoAssetInfo) -> Bool {
        guard let requested = frameRate.requestedFPS else { return false }
        return requested > info.sourceFPS + 0.5
    }

    func canRunFrameRate(for info: VideoAssetInfo) -> Bool {
        !needsFrameGeneration(for: info)
    }

    /// Export supports resampling to these sizes; the UI identifies upscaling.
    static func supportedResolutions(for info: VideoAssetInfo) -> [Resolution] {
        Resolution.allCases
    }

    /// Offer native cadence conversion and the implemented 2x motion path only.
    static func supportedFrameRates(for info: VideoAssetInfo) -> [FrameRate] {
        FrameRate.allCases.filter { frameRate in
            guard let target = frameRate.requestedFPS else { return true }
            return FrameGenerationPlan.make(sourceFPS: info.sourceFPS, targetFPS: target) != nil
        }
    }

    func isPassThrough(for info: VideoAssetInfo) -> Bool {
        resolution == .source && frameRate == .source && codec == .source
    }

    private func evenSize(width: CGFloat, height: CGFloat) -> CGSize {
        let evenWidth = max(2, Int(width.rounded()) / 2 * 2)
        let evenHeight = max(2, Int(height.rounded()) / 2 * 2)
        return CGSize(width: evenWidth, height: evenHeight)
    }
}
