import Foundation

struct OptimizationPreset: Identifiable, Hashable, Sendable {
    enum Codec: String, Sendable {
        case passthrough
        case h264
        case hevc
    }

    let id: String
    let title: String
    let subtitle: String
    let codec: Codec
    let maximumFPS: Double?
    let isPlatformPreset: Bool

    static let original = OptimizationPreset(
        id: "original",
        title: "نسخة أصلية",
        subtitle: "نسخ الملف بدون ادعاء تحسين أو تغيير FPS",
        codec: .passthrough,
        maximumFPS: nil,
        isPlatformPreset: false
    )

    static let tiktok = OptimizationPreset(
        id: "tiktok",
        title: "TikTok · موصى به",
        subtitle: "H.264 مع حد أقصى 60fps وفق قيود Content Posting API",
        codec: .h264,
        maximumFPS: 60,
        isPlatformPreset: true
    )

    static let hevc = OptimizationPreset(
        id: "hevc",
        title: "HEVC · جودة عالية",
        subtitle: "HEVC بأعلى preset متاح مع الحفاظ على cadence المصدر",
        codec: .hevc,
        maximumFPS: nil,
        isPlatformPreset: false
    )

    static let all: [OptimizationPreset] = [.tiktok, .hevc, .original]
}
