import Foundation

struct VideoRecommendation: Equatable, Sendable {
    let processing: VideoProcessingSettings
    let enhancement: VideoEnhancementSettings
    let titleArabic: String
    let titleEnglish: String
    let explanationArabic: String
    let explanationEnglish: String

    func title(isArabic: Bool) -> String {
        isArabic ? titleArabic : titleEnglish
    }

    func explanation(isArabic: Bool) -> String {
        isArabic ? explanationArabic : explanationEnglish
    }
}

enum VideoRecommendationEngine {
    static func recommend(info: VideoAssetInfo, report: VideoAnalysisReport) -> VideoRecommendation {
        let processing = recommendedProcessing(info: info, report: report)
        let enhancement = recommendedEnhancement(report: report)
        let copy = recommendationCopy(info: info, report: report, processing: processing, enhancement: enhancement)

        return VideoRecommendation(
            processing: processing,
            enhancement: enhancement,
            titleArabic: copy.arTitle,
            titleEnglish: copy.enTitle,
            explanationArabic: copy.arExplanation,
            explanationEnglish: copy.enExplanation
        )
    }

    private static func recommendedProcessing(
        info: VideoAssetInfo,
        report: VideoAnalysisReport
    ) -> VideoProcessingSettings {
        let sourceLongEdge = max(info.width, info.height)

        let resolution: VideoProcessingSettings.Resolution
        if sourceLongEdge < 1280,
           report.sharpnessScore >= 0.24,
           report.noiseScore < 0.44,
           report.compressionArtifactScore < 0.48 {
            resolution = .fullHD
        } else {
            resolution = .source
        }

        let frameRate: VideoProcessingSettings.FrameRate
        if info.sourceFPS >= 59.5 {
            frameRate = .fps60
        } else if info.sourceFPS >= 23.0,
                  info.sourceFPS <= 30.5,
                  report.motionLevel != .low,
                  FrameGenerationPlan.make(sourceFPS: info.sourceFPS, targetFPS: 60) != nil {
            frameRate = .fps60
        } else {
            frameRate = .source
        }

        let codec: VideoProcessingSettings.Codec
        if info.videoCodec.localizedCaseInsensitiveContains("HEVC") ||
            info.videoCodec.localizedCaseInsensitiveContains("H.265") {
            codec = .hevc
        } else {
            codec = .source
        }

        return VideoProcessingSettings(
            resolution: resolution,
            frameRate: frameRate,
            codec: codec
        )
    }

    private static func recommendedEnhancement(report: VideoAnalysisReport) -> VideoEnhancementSettings {
        let denoise = clamp(
            max(0, report.noiseScore - 0.08) * 0.70 +
            max(0, report.compressionArtifactScore - 0.10) * 0.26,
            maximum: 0.55
        )

        let softnessNeed = max(0, 0.42 - report.sharpnessScore)
        let detailRecovery = clamp(
            softnessNeed * 0.78 + report.compressionArtifactScore * 0.12,
            maximum: 0.42
        )

        let sharpening = clamp(
            max(0, 0.30 - report.sharpnessScore) * 0.34,
            maximum: 0.16
        )

        let colorBoost: Double
        if report.saturationScore < 0.18 && report.colorCastScore < 0.24 {
            colorBoost = min(0.10, (0.18 - report.saturationScore) * 0.42)
        } else {
            colorBoost = 0
        }

        let exposure: Double
        if report.averageLuminance < 0.28 && report.highlightClippingRatio < 0.025 {
            exposure = min(0.16, max(0, (0.31 - report.averageLuminance) * 0.55))
        } else if report.averageLuminance > 0.72 && report.highlightClippingRatio > 0.06 {
            exposure = max(-0.12, -(report.averageLuminance - 0.68) * 0.35)
        } else {
            exposure = 0
        }

        let contrast: Double
        if report.luminanceDeviation < 0.14 && !report.isLowLight {
            contrast = min(0.08, (0.14 - report.luminanceDeviation) * 0.40)
        } else {
            contrast = 0
        }

        let values = [denoise, detailRecovery, sharpening, colorBoost, abs(exposure), abs(contrast)]
        let hasTreatment = values.contains { $0 > 0.015 }

        return VideoEnhancementSettings(
            mode: hasTreatment ? .smart : .off,
            denoise: denoise,
            detailRecovery: detailRecovery,
            sharpening: sharpening,
            colorBoost: colorBoost,
            exposure: exposure,
            contrast: contrast
        )
    }

    private static func recommendationCopy(
        info: VideoAssetInfo,
        report: VideoAnalysisReport,
        processing: VideoProcessingSettings,
        enhancement: VideoEnhancementSettings
    ) -> (arTitle: String, enTitle: String, arExplanation: String, enExplanation: String) {
        var arReasons: [String] = []
        var enReasons: [String] = []

        if report.isLowLight {
            arReasons.append("الإضاءة منخفضة")
            enReasons.append("low light")
        }
        if report.isNoisy {
            arReasons.append("يوجد تشويش ملحوظ")
            enReasons.append("visible noise")
        }
        if report.isCompressionStressed {
            arReasons.append("آثار الضغط واضحة")
            enReasons.append("compression artifacts")
        }
        if report.isSoft {
            arReasons.append("التفاصيل ناعمة")
            enReasons.append("soft detail")
        }
        if report.motionLevel == .high {
            arReasons.append("الحركة سريعة")
            enReasons.append("fast motion")
        } else if report.motionLevel == .medium {
            arReasons.append("الحركة متوسطة")
            enReasons.append("moderate motion")
        }

        let recommendsSmootherMotion = processing.frameRate == .fps60 && info.sourceFPS < 59.5
        let treatmentEnabled = enhancement.isEnabled

        let arTitle: String
        let enTitle: String
        if recommendsSmootherMotion && treatmentEnabled {
            arTitle = "ترميم متوازن وحركة أنعم"
            enTitle = "Balanced restoration and smoother motion"
        } else if recommendsSmootherMotion {
            arTitle = "حركة أنعم"
            enTitle = "Smoother motion"
        } else if treatmentEnabled {
            arTitle = "ترميم متوازن"
            enTitle = "Balanced restoration"
        } else {
            arTitle = "الحفاظ على الأصل"
            enTitle = "Preserve the source"
        }

        let arExplanation: String
        let enExplanation: String
        if arReasons.isEmpty {
            arExplanation = "الفيديو متوازن في العينات التي فحصناها، لذلك التوصية محافظة ولا تضيف معالجة غير ضرورية."
            enExplanation = "The sampled frames are already balanced, so the recommendation stays conservative and avoids unnecessary processing."
        } else {
            arExplanation = "رصدنا \(arReasons.joined(separator: "، ")). التوصية تعالج ما يحتاجه الفيديو فقط وتحافظ على شكل اللقطة الطبيعي."
            enExplanation = "We detected \(enReasons.joined(separator: ", ")). The recommendation targets only what needs attention and keeps the footage natural."
        }

        return (arTitle, enTitle, arExplanation, enExplanation)
    }

    private static func clamp(_ value: Double, maximum: Double) -> Double {
        min(maximum, max(0, value))
    }
}
