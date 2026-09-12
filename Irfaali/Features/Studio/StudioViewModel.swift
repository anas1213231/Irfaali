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
        case frameGenerationVerificationFailed([String])
        case frameGenerationVerificationUnavailable(String)

        var errorDescription: String? {
            switch self {
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
    @Published var settings: VideoProcessingSettings = .standard
    @Published var enhancement: VideoEnhancementSettings = .off
    @Published private(set) var isAnalyzing = false
    @Published private(set) var isProcessing = false
    @Published private(set) var processingStage: ProcessingStage = .idle
    @Published private(set) var progress: Double = 0
    @Published private(set) var generatedFrameCount = 0
    @Published private(set) var frameGenerationVerification: FrameGenerationVerification?
    @Published private(set) var lastOutcome: ExportOutcome?
    @Published private(set) var validationMessage: String?
    @Published private(set) var saveState: SaveState = .idle
    @Published var errorMessage: String?

    private let analyzer = VideoAnalyzer()
    private let exporter = VideoExportService()
    private let frameGenerator = FrameGenerationService()
    private let enhancer = VideoEnhancementService()
    private let photoSaver = PhotoLibrarySaver()

    /// Frame generation stays gated in the public Studio button until device QA is
    /// complete. The real engine is already wired into `process()` so QA/internal
    /// calls exercise the exact production pipeline instead of a mock path.
    var canProcess: Bool {
        guard let info else { return false }
        return !settings.needsFrameGeneration(for: info) && !isAnalyzing && !isProcessing
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

    var processingStageTextArabic: String {
        switch processingStage {
        case .idle:
            return "جاهزين متى ما أنت جاهز 😎"
        case .preparing:
            return "نجهّز المحرك…"
        case .exporting:
            return "قاعدين نبني الملف مضبوط 🔥"
        case .generatingFrames:
            return "نولد فريمات جديدة بالحركة 🧠⚡️"
        case .enhancing:
            return "نلمّع التفاصيل الحين ✨"
        case .verifying:
            return "آخر فحص يا وحش 👀"
        case .complete:
            return "خلصناها صح ✅"
        }
    }

    var processingStageTextEnglish: String {
        switch processingStage {
        case .idle:
            return "Ready when you are."
        case .preparing:
            return "Preparing the engine…"
        case .exporting:
            return "Building the output…"
        case .generatingFrames:
            return "Generating motion-aware frames…"
        case .enhancing:
            return "Enhancing image details…"
        case .verifying:
            return "Running final verification…"
        case .complete:
            return "Processing complete."
        }
    }

    func importVideo(url: URL) async {
        isAnalyzing = true
        processingStage = .idle
        generatedFrameCount = 0
        frameGenerationVerification = nil
        errorMessage = nil
        validationMessage = nil
        lastOutcome = nil
        outputInfo = nil
        saveState = .idle
        defer { isAnalyzing = false }

        do {
            let analyzed = try await analyzer.analyze(url: url)
            info = analyzed
            settings = VideoProcessingSettings.recommended(for: analyzed)
            enhancement = .smart(for: analyzed)
        } catch {
            info = nil
            errorMessage = error.localizedDescription
        }
    }

    func applyRecommendedSettings() {
        guard let info else { return }
        settings = VideoProcessingSettings.recommended(for: info)
        enhancement = .smart(for: info)
    }

    func applyEnhancementMode(_ mode: VideoEnhancementSettings.Mode) {
        guard let info else {
            enhancement = mode == .off ? .off : enhancement
            return
        }
        enhancement = .preset(mode, info: info)
    }

    func updateEnhancement(_ keyPath: WritableKeyPath<VideoEnhancementSettings, Double>, value: Double) {
        enhancement[keyPath: keyPath] = min(max(value, 0), 1)
        enhancement.markCustom()
    }

    func process() async -> ExportOutcome? {
        guard let info else { return nil }
        isProcessing = true
        processingStage = .preparing
        progress = 0
        generatedFrameCount = 0
        frameGenerationVerification = nil
        errorMessage = nil
        validationMessage = nil
        lastOutcome = nil
        outputInfo = nil
        saveState = .idle
        defer { isProcessing = false }

        do {
            let usesEnhancement = enhancement.isEnabled
            let wantsFrameGeneration = settings.needsFrameGeneration(for: info)
            let generationPlan = wantsFrameGeneration ? frameGenerationPlan : nil

            if wantsFrameGeneration, generationPlan?.strategy != .opticalFlow2x {
                throw FrameGenerationService.GenerationError.unsupportedPlan
            }

            let resolvedPreferHEVC = settings.codec == .hevc || (
                settings.codec == .source &&
                (info.videoCodec.localizedCaseInsensitiveContains("HEVC") || info.videoCodec.localizedCaseInsensitiveContains("H.265"))
            )

            // Geometry / codec preparation must happen at the source cadence. The
            // frame generator then creates genuinely new temporal samples.
            var baseSettings = settings
            if wantsFrameGeneration {
                baseSettings.frameRate = .source
            }

            let exportEnd: Double
            let generationStart: Double
            let generationEnd: Double
            let enhancementStart: Double

            if wantsFrameGeneration && usesEnhancement {
                exportEnd = 0.16
                generationStart = 0.16
                generationEnd = 0.78
                enhancementStart = 0.78
            } else if wantsFrameGeneration {
                exportEnd = 0.20
                generationStart = 0.20
                generationEnd = 0.96
                enhancementStart = 0.96
            } else if usesEnhancement {
                exportEnd = 0.70
                generationStart = 0.70
                generationEnd = 0.70
                enhancementStart = 0.70
            } else {
                exportEnd = 0.96
                generationStart = 0.96
                generationEnd = 0.96
                enhancementStart = 0.96
            }

            processingStage = .exporting
            let baseResult = try await exporter.export(info: info, settings: baseSettings) { [weak self] value in
                Task { @MainActor in
                    self?.progress = min(max(value * exportEnd, 0), exportEnd)
                }
            }

            var finalResult = baseResult
            var generationResult: FrameGenerationService.Result?

            if wantsFrameGeneration,
               let generationPlan,
               generationPlan.strategy == .opticalFlow2x {
                processingStage = .generatingFrames

                let generated = try await frameGenerator.generate2x(
                    sourceURL: baseResult.url,
                    sourceFPS: info.sourceFPS,
                    targetFPS: generationPlan.targetFPS,
                    estimatedBitrate: info.estimatedBitrate,
                    preferHEVC: resolvedPreferHEVC
                ) { [weak self] value in
                    Task { @MainActor in
                        let span = generationEnd - generationStart
                        self?.progress = min(
                            max(generationStart + value * span, generationStart),
                            generationEnd
                        )
                    }
                }

                generationResult = generated
                generatedFrameCount = generated.generatedFrameCount
                if generated.url != baseResult.url {
                    try? FileManager.default.removeItem(at: baseResult.url)
                }

                finalResult = ExportOutcome(
                    url: generated.url,
                    sourceFPS: info.sourceFPS,
                    outputFPS: generated.targetFPS,
                    fpsMode: .interpolated,
                    codecLabel: resolvedPreferHEVC ? "H.265 / HEVC" : "H.264 / AVC"
                )
            }

            if usesEnhancement {
                processingStage = .enhancing
                let inputURL = finalResult.url
                let enhancedURL = try await enhancer.enhance(
                    sourceURL: inputURL,
                    settings: enhancement,
                    preferHEVC: resolvedPreferHEVC
                ) { [weak self] value in
                    Task { @MainActor in
                        let end = 0.97
                        let span = max(end - enhancementStart, 0.01)
                        self?.progress = min(
                            max(enhancementStart + value * span, enhancementStart),
                            end
                        )
                    }
                }

                if enhancedURL != inputURL {
                    try? FileManager.default.removeItem(at: inputURL)
                }

                finalResult = ExportOutcome(
                    url: enhancedURL,
                    sourceFPS: finalResult.sourceFPS,
                    outputFPS: finalResult.outputFPS,
                    fpsMode: finalResult.fpsMode,
                    codecLabel: finalResult.codecLabel
                )
            }

            processingStage = .verifying
            progress = max(progress, 0.98)

            do {
                let analyzedOutput = try await analyzer.analyze(url: finalResult.url)
                outputInfo = analyzedOutput

                if let generationResult {
                    let verification = FrameGenerationVerification.verify2x(
                        sourceFrameCount: generationResult.sourceFrameCount,
                        generatedFrameCount: generationResult.generatedFrameCount,
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
                }
            } catch let error as ProcessingError {
                throw error
            } catch {
                validationMessage = "تم إنشاء الملف، لكن تعذر التحقق التقني بعد التصدير: \(error.localizedDescription)"
                if wantsFrameGeneration {
                    try? FileManager.default.removeItem(at: finalResult.url)
                    outputInfo = nil
                    throw ProcessingError.frameGenerationVerificationUnavailable(error.localizedDescription)
                }
            }

            lastOutcome = finalResult
            progress = 1
            processingStage = .complete
            return finalResult
        } catch {
            processingStage = .idle
            progress = 0
            lastOutcome = nil
            errorMessage = error.localizedDescription
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
            saveState = .failed(error.localizedDescription)
        }
    }
}
