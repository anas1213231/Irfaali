import Foundation

struct VideoEnhancementSettings: Equatable, Sendable {
    enum Mode: String, CaseIterable, Identifiable, Sendable {
        case off
        case smart
        case clean
        case detail
        case custom

        var id: String { rawValue }

        func title(isArabic: Bool) -> String {
            switch self {
            case .off: return isArabic ? "بدون" : "Off"
            case .smart: return isArabic ? "ذكي" : "Smart"
            case .clean: return isArabic ? "تنظيف" : "Clean"
            case .detail: return isArabic ? "تفاصيل" : "Detail"
            case .custom: return isArabic ? "يدوي" : "Custom"
            }
        }
    }

    var mode: Mode = .off
    var denoise: Double = 0
    var detailRecovery: Double = 0
    var sharpening: Double = 0
    var colorBoost: Double = 0

    static let off = VideoEnhancementSettings()

    static func smart(for info: VideoAssetInfo) -> VideoEnhancementSettings {
        let pixels = Double(max(info.width * info.height, 1))
        let fps = max(info.sourceFPS, 1)
        let bitsPerPixelPerFrame = info.estimatedBitrate > 0
            ? info.estimatedBitrate / (pixels * fps)
            : 0.08

        let compressionStress: Double
        switch bitsPerPixelPerFrame {
        case ..<0.045: compressionStress = 1.0
        case ..<0.075: compressionStress = 0.72
        case ..<0.12: compressionStress = 0.46
        default: compressionStress = 0.24
        }

        let longEdge = max(info.width, info.height)
        let detailNeed = longEdge < 1600 ? 0.56 : (longEdge < 2300 ? 0.38 : 0.24)

        return VideoEnhancementSettings(
            mode: .smart,
            denoise: clamp(0.16 + compressionStress * 0.34),
            detailRecovery: clamp(detailNeed + compressionStress * 0.16),
            sharpening: clamp(0.14 + detailNeed * 0.34),
            colorBoost: clamp(info.dynamicRange.uppercased().contains("HDR") ? 0.06 : 0.14)
        )
    }

    static func preset(_ mode: Mode, info: VideoAssetInfo) -> VideoEnhancementSettings {
        switch mode {
        case .off:
            return .off
        case .smart:
            return smart(for: info)
        case .clean:
            return VideoEnhancementSettings(
                mode: .clean,
                denoise: 0.62,
                detailRecovery: 0.24,
                sharpening: 0.12,
                colorBoost: 0.08
            )
        case .detail:
            return VideoEnhancementSettings(
                mode: .detail,
                denoise: 0.18,
                detailRecovery: 0.68,
                sharpening: 0.48,
                colorBoost: 0.12
            )
        case .custom:
            return VideoEnhancementSettings(
                mode: .custom,
                denoise: 0.2,
                detailRecovery: 0.3,
                sharpening: 0.24,
                colorBoost: 0.1
            )
        }
    }

    var isEnabled: Bool {
        mode != .off && (denoise > 0.001 || detailRecovery > 0.001 || sharpening > 0.001 || colorBoost > 0.001)
    }

    mutating func markCustom() {
        if mode != .off { mode = .custom }
    }

    func normalized() -> VideoEnhancementSettings {
        VideoEnhancementSettings(
            mode: mode,
            denoise: Self.clamp(denoise),
            detailRecovery: Self.clamp(detailRecovery),
            sharpening: Self.clamp(sharpening),
            colorBoost: Self.clamp(colorBoost)
        )
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
