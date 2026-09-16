import Combine
import Foundation

@MainActor
final class StudioViewModel: ObservableObject {
    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(String)
    }

    enum AnalysisStage: Equatable {
        case idle
        case readingMetadata
        case samplingFrames
        case preparingRecommendation
        case complete
    }

    enum ProcessingStage: Equatable {
        case idle
        case preparing
        case exporting
        case generatingFrames
        case enhancing
        case verifying
        case complete
    }

    enum ProcessingError: LocalizedError {
        case outputMismatch(String)
        case frameGenerationDeviceBlocked([String])
        case frameGenerationVerificationFailed([String])
        case frameGenerationVerificationUnavailable(String)

        var errorDescription: String? {
            switch self {
            case .outputMismatch(let reason):
                return "ما اعتمدنا الملف لأن النتيجة ما طابقت الطلب: \(reason)"
            case .frameGenerationDeviceBlocked(let reasons):
                return "محرك الفريمات وقف قبل يبدأ عشان نحمي الجودة والجهاز: \(reasons.joined(separator: " · "))"
            case .frameGenerationVerificationFailed(let failures):
                let details = failures.joined(separator: " · ")
                return "ارفعلي وقف الملف لأن فحص الفريمات ما عدى: \(details)"
            case .frameGenerationVerificationUnavailable(let reason):
                return "توليد الفريمات خلص، بس ما قدرنا نثبت النتيجة تقنيًا، لذلك ما راح نعتمد الملف: \(reason)"
            }
        }
    }

    @Published private(set) var info: VideoAssetInfo?
    @Published private(set) var outputInfo: VideoAssetInfo?
    @Published private(set) var analysisReport: VideoAnalysisReport?
    @Published private(set) var recommendation: VideoRecommendation?
    @Published var settings: VideoProcessingSettings = .standard
    @Published var enhancement: VideoEnhancementSettings = .off
    @Published private(set) var isAnalyzing = false
    @Published private(set) var analysisStage: AnalysisStage = .idle
    @Published private(set) var isProcessing = false
    @Published private(set) var processingStage: ProcessingStage = .idle
    @Published private(set) var progress: Double = 0
    @Published private(set) var generatedFrameCount = 0
    @Published private(set) var sceneCutFallbackFrameCount = 0
    @Published private(set) var frameGenerationVerification: FrameGenerationVerification?
    @Published private(set) var cadenceAudit: VideoCadenceAudit.Report?
    @Published private(set) var lastOutcome: ExportOutcome?
    @Published private(set) var validationMessage: String?
    @Published private(set) var saveState: SaveState = .idle
    @Published var errorMessage: String?

    var isArabic = true

    private func message(_ error: Error) -> String {
        AppErrorMessage.describe(error, isArabic: isArabic)
    }

    private let analyzer = VideoAnalyzer()
    private let contentAnalyzer = VideoContentAnalyzer()
    private let exporter = VideoExportService()
    private let frameGenerator = FrameGenerationService()
    private let enhancer = VideoEnhancementService()
    private let photoSaver = PhotoLibrarySaver()
    private var activeProcessingTask: Task<ExportOutcome?, Never>?

    /// Every selected operation must have an implemented, device-ready path.
    var canProcess: Bool {
        guard let info, !isAnalyzing, !isProcessing else { return false }
        guard VideoProcessingSettings.supportedResolutions(for: info).contains(settings.resolution),
              VideoProcessingSettings.supportedFrameRates(for: info).contains(settings.frameRate) else {
            return false
        }
        return !settings.needsFrameGeneration(for: info) || frameGenerationReadiness?.canStart == true
    }

    var canCancelProcessing: Bool {
        isProcessing && activeProcessingTask != nil
    }

    var needsFrameGeneration: Bool {
        guard let info else { return false }
        return settings.needsFrameGeneration(for: info)
    }

    var frameGenerationPlan: FrameGenerationPlan? {
        guard let info,
              let target = settings.frameRate.requestedFPS,
              target > info.sourceFPS + 0.5 else {
            return nil
        }
        return FrameGenerationPlan.make(sourceFPS: info.sourceFPS, targetFPS: target)
    }

    var frameGenerationReadiness: FrameGenerationReadiness? {
        guard let info, let plan = frameGenerationPlan else { return nil }
        let size = VideoProcessingSettings(resolution: .source).targetSize(for: info)
        return FrameGenerationReadiness.evaluate(
            plan: plan,
            width: Int(size.width.rounded()),
            height: Int(size.height.rounded()),
            environment: .current()
        )
    }

    var analysisStageTextArabic: String {
        switch analysisStage {
        case .idle:
            return "جاهز للتحليل"
        case .readingMetadata:
            return "قراءة الفيديو"
        case .samplingFrames:
            return "تحليل اللقطات"
        case .preparingRecommendation:
            return "إعداد التوصية"
        case .complete:
            return "اكتمل التحليل"
        }
    }

    var analysisStageTextEnglish: String {
        switch analysisStage {
        case .idle:
            return "Ready to analyze"
        case .readingMetadata:
            return "Reading video"
        case .samplingFrames:
            return "Analyzing frames"
        case .preparingRecommendation:
            return "Preparing recommendation"
        case .complete:
            return "Analysis complete"
        }
    }

    var processingStageTextArabic: String {
        switch processingStage {
        case .idle:
            return "جاهز للمعالجة"
        case .preparing:
            return "نجهّز المحرك…"
        case .exporting:
            return "جاري إنشاء الملف"
        case .generatingFrames:
            return "جاري تجهيز الفريمات"
        case .enhancing:
            return "جاري تحسين الصورة"
        case .verifying:
            return "جاري التحقق من النتيجة"
        case .complete:
            return "اكتملت المعالجة"
        }
    }

    var processingStageTextEnglish: String {
        switch processingStage {
        case .idle:
            return "Ready to process"
        case .preparing:
            return "Preparing the video…"
        case .exporting:
            return "Creating the output…"
        case .generatingFrames:
            return "Preparing frames…"
        case .enhancing:
            return "Enhancing the image…"
        case .verifying:
            return "Verifying the result…"
        case .complete:
            return "Processing complete"
        }
    }

    func importVideo(url: URL) async {
        cancelProcessing()
        if let activeProcessingTask { _ = await activeProcessingTask.value }

        isAnalyzing = true
        analysisStage = .readingMetadata
        processingStage = .idle
        generatedFrameCount = 0
        sceneCutFallbackFrameCount = 0
        frameGenerationVerification = nil
        cadenceAudit = nil
        errorMessage = nil
        validationMessage = nil
        lastOutcome = nil
        outputInfo = nil
        analysisReport = nil
        recommendation = nil
        saveState = .idle

        // Import never silently changes the picture. A recommendation is prepared
        // separately and only becomes active after explicit user confirmation.
        settings = VideoProcessingSettings(resolution: .source, frameRate: .source, codec: .source)
        enhancement = .off

        defer { isAnalyzing = false }

        do {
            let analyzed = try await analyzer.analyze(url: url)
            info = analyzed

            analysisStage = .samplingFrames
            let report: VideoAnalysisReport
            do {
                report = try await contentAnalyzer.analyze(info: analyzed)
            } catch {
                // A frame-analysis failure must not make an otherwise valid video unusable.
                // The fallback is deliberately conservative and avoids inventing defects.
                report = .metadataOnlyFallback
            }
            analysisReport = report

            analysisStage = .preparingRecommendation
            recommendation = VideoRecommendationEngine.recommend(info: analyzed, report: report)
            analysisStage = .complete
        } catch {
            info = nil
            analysisReport = nil
            recommendation = nil
            analysisStage = .idle
            errorMessage = message(error)
        }
    }

    func applyRecommendedSettings() {
        if let recommendation {
            settings = recommendation.processing
            enhancement = recommendation.enhancement
            return
        }

        guard let info else { return }
        settings = VideoProcessingSettings.recommended(for: info)
        enhancement = .smart(for: info)
    }

    func applyEnhancementMode(_ mode: VideoEnhancementSettings.Mode) {
        guard let info else {
            enhancement = mode == .off ? .off : enhancement
            return
        }

        if mode == .smart, let recommendation {
            enhancement = recommendation.enhancement
        } else {
            enhancement = .preset(mode, info: info)
        }
    }

    func updateEnhancement(_ keyPath: WritableKeyPath<VideoEnhancementSettings, Double>, value: Double) {
        let lower: Double = keyPath == \VideoEnhancementSettings.exposure || keyPath == \VideoEnhancementSettings.contrast ? -1 : 0
        enhancement[keyPath: keyPath] = min(max(value, lower), 1)
        enhancement.markCustom()
    }

    func process() async -> ExportOutcome? {
        if let activeProcessingTask {
            return await activeProcessingTask.value
        }

        let task = Task { [weak self] () -> ExportOutcome? in
            guard let self else { return nil }
            return await self.performProcessing()
        }
        activeProcessingTask = task

        let result = await task.value
        activeProcessingTask = nil
        return result
    }

    func cancelProcessing() {
        activeProcessingTask?.cancel()
    }

    private func performProcessing() async -> ExportOutcome? {
        guard let info else { return nil }
        isProcessing = true
        processingStage = .preparing
        progress = 0
        generatedFrameCount = 0
        sceneCutFallbackFrameCount = 0
        frameGenerationVerification = nil
        cadenceAudit = nil
        errorMessage = nil
        validationMessage = nil
        lastOutcome = nil
        outputInfo = nil
        saveState = .idle
        defer { isProcessing = false }

        var transientURLs = Set<URL>()

        do {
            try Task.checkCancellation()

            guard VideoProcessingSettings.supportedResolutions(for: info).contains(settings.resolution),
                  VideoProcessingSettings.supportedFrameRates(for: info).contains(settings.frameRate) else {
                throw ProcessingError.outputMismatch("اختر إعدادًا مناسبًا لخصائص الفيديو.")
            }

            let usesEnhancement = enhancement.isEnabled
            let wantsFrameGeneration = settings.needsFrameGeneration(for: info)
            let generationPlan = wantsFrameGeneration ? frameGenerationPlan : nil

            if wantsFrameGeneration, generationPlan?.strategy != .opticalFlow2x {
                throw FrameGenerationService.GenerationError.unsupportedPlan
            }

            if wantsFrameGeneration,
               let readiness = frameGenerationReadiness,
               !readiness.canStart {
                throw ProcessingError.frameGenerationDeviceBlocked(
                    readiness.reasons.map(\.description)
                )
            }

            let resolvedPreferHEVC = settings.codec == .hevc || (
                settings.codec == .source &&
                (info.videoCodec.localizedCaseInsensitiveContains("HEVC") || info.videoCodec.localizedCaseInsensitiveContains("H.265"))
            )

            var workingURL = info.url
            var generationResult: FrameGenerationService.Result?
            let generationStart = usesEnhancement ? 0.25 : 0.02
            let generationEnd = 0.75
            let finalStart = wantsFrameGeneration ? generationEnd : (usesEnhancement ? 0.25 : 0.02)

            // Image adjustments run at source cadence and resolution. This avoids
            // filtering 120 full-size 4K frames for each second of a 30 FPS source.
            if usesEnhancement {
                processingStage = .enhancing
                workingURL = try await enhancer.enhance(sourceURL: workingURL,
                    settings: enhancement, preferHEVC: resolvedPreferHEVC) { [weak self] value in
                    Task { @MainActor in self?.progress = min(0.25, max(0.02, value * 0.25)) }
                }
                transientURLs.insert(workingURL)
            }
            try Task.checkCancellation()

            if wantsFrameGeneration, let generationPlan {
                processingStage = .generatingFrames
                let generated = try await frameGenerator.generate2x(
                    sourceURL: workingURL, sourceFPS: info.sourceFPS,
                    targetFPS: generationPlan.targetFPS, estimatedBitrate: info.estimatedBitrate,
                    preferHEVC: resolvedPreferHEVC
                ) { [weak self] value in
                    Task { @MainActor in
                        self?.progress = generationStart + min(1, max(0, value)) * (generationEnd - generationStart)
                    }
                }
                generationResult = generated
                generatedFrameCount = generated.generatedFrameCount
                sceneCutFallbackFrameCount = generated.sceneCutFallbackFrameCount
                if transientURLs.contains(workingURL) {
                    try? FileManager.default.removeItem(at: workingURL)
                    transientURLs.remove(workingURL)
                }
                workingURL = generated.url
                transientURLs.insert(workingURL)
            }
            try Task.checkCancellation()

            // Final geometry/codec stage always reports progress, including 4K/120.
            processingStage = .exporting
            progress = finalStart
            let workingInfo = workingURL == info.url ? info : try await analyzer.analyze(url: workingURL)
            var finalSettings = settings
            if wantsFrameGeneration { finalSettings.frameRate = .source }
            let encoded = try await exporter.export(info: workingInfo, settings: finalSettings) { [weak self] value in
                Task { @MainActor in
                    self?.progress = finalStart + min(1, max(0, value)) * (0.97 - finalStart)
                }
            }
            transientURLs.insert(encoded.url)
            if transientURLs.contains(workingURL), workingURL != encoded.url {
                try? FileManager.default.removeItem(at: workingURL)
                transientURLs.remove(workingURL)
            }
            let finalResult = ExportOutcome(url: encoded.url, sourceFPS: info.sourceFPS,
                outputFPS: wantsFrameGeneration ? (generationPlan?.targetFPS ?? encoded.outputFPS) : encoded.outputFPS,
                fpsMode: wantsFrameGeneration ? .interpolated : encoded.fpsMode,
                codecLabel: encoded.codecLabel)

            try Task.checkCancellation()
            processingStage = .verifying
            progress = max(progress, 0.98)

            do {
                let analyzedOutput = try await analyzer.analyze(url: finalResult.url)
                if let mismatch = OutputVerification.mismatch(source: info, output: analyzedOutput, settings: settings) {
                    throw ProcessingError.outputMismatch(mismatch)
                }
                outputInfo = analyzedOutput

                if let generationResult {
                    let encodedCount = try await VideoSampleAudit.frameCount(url: finalResult.url)
                    let expectedCount = generationResult.sourceFrameCount + generationResult.generatedFrameCount + generationResult.sceneCutFallbackFrameCount
                    guard encodedCount == expectedCount else {
                        throw ProcessingError.outputMismatch("Expected \(expectedCount) encoded frames; found \(encodedCount).")
                    }

                    let verification = FrameGenerationVerification.verify2x(
                        sourceFrameCount: generationResult.sourceFrameCount,
                        generatedFrameCount: generationResult.generatedFrameCount,
                        sceneCutFallbackFrameCount: generationResult.sceneCutFallbackFrameCount,
                        expectedFPS: generationResult.targetFPS,
                        actualFPS: analyzedOutput.sourceFPS
                    )
                    frameGenerationVerification = verification

                    if case .failed(let failures) = verification.status {
                        let details = failures.map(\.description)
                        validationMessage = details.joined(separator: " · ")
                        try? FileManager.default.removeItem(at: finalResult.url)
                        outputInfo = nil
                        throw ProcessingError.frameGenerationVerificationFailed(details)
                    }

                    // Nominal track metadata can say 60/120 FPS even when cadence is
                    // irregular. Read the encoded samples back and require timing
                    // evidence before accepting a generated-frame-rate result.
                    let cadence = try await VideoCadenceAudit.audit(url: finalResult.url)
                    cadenceAudit = cadence
                    let expectedFPS = generationResult.targetFPS
                    let fpsTolerance = max(0.75, expectedFPS * 0.015)

                    guard abs(cadence.estimatedFPS - expectedFPS) <= fpsTolerance else {
                        throw ProcessingError.outputMismatch(
                            String(format: "Cadence measured %.2f FPS; expected %.2f FPS.", cadence.estimatedFPS, expectedFPS)
                        )
                    }

                    guard cadence.hasStableTimestamps else {
                        throw ProcessingError.outputMismatch(
                            String(format: "Frame timing is unstable (jitter %.3f).", cadence.intervalJitterRatio)
                        )
                    }
                }
            } catch let error as ProcessingError {
                throw error
            } catch {
                outputInfo = nil
                cadenceAudit = nil
                throw ProcessingError.outputMismatch(error.localizedDescription)
            }

            try Task.checkCancellation()
            lastOutcome = finalResult
            transientURLs.remove(finalResult.url)
            progress = 1
            processingStage = .complete
            return finalResult
        } catch is CancellationError {
            transientURLs.forEach { try? FileManager.default.removeItem(at: $0) }
            processingStage = .idle
            progress = 0
            lastOutcome = nil
            outputInfo = nil
            cadenceAudit = nil
            validationMessage = nil
            errorMessage = isArabic ? "أُلغيت المعالجة." : "Processing cancelled."
            return nil
        } catch {
            transientURLs.forEach { try? FileManager.default.removeItem(at: $0) }
            processingStage = .idle
            progress = 0
            lastOutcome = nil
            outputInfo = nil
            cadenceAudit = nil
            errorMessage = message(error)
            return nil
        }
    }

    func saveOutputToPhotos() async {
        guard let url = lastOutcome?.url else { return }
        saveState = .saving

        do {
            try await photoSaver.saveVideo(at: url)
            saveState = .saved
        } catch {
            saveState = .failed(message(error))
        }
    }
}
