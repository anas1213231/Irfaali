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

    @Published private(set) var info: VideoAssetInfo?
    @Published private(set) var outputInfo: VideoAssetInfo?
    @Published var settings: VideoProcessingSettings = .standard
    @Published var enhancement: VideoEnhancementSettings = .off
    @Published private(set) var isAnalyzing = false
    @Published private(set) var isProcessing = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var lastOutcome: ExportOutcome?
    @Published private(set) var validationMessage: String?
    @Published private(set) var saveState: SaveState = .idle
    @Published var errorMessage: String?

    private let analyzer = VideoAnalyzer()
    private let exporter = VideoExportService()
    private let enhancer = VideoEnhancementService()
    private let photoSaver = PhotoLibrarySaver()

    var canProcess: Bool {
        guard let info else { return false }
        return !settings.needsFrameGeneration(for: info) && !isAnalyzing && !isProcessing
    }

    var needsFrameGeneration: Bool {
        guard let info else { return false }
        return settings.needsFrameGeneration(for: info)
    }

    var processingStageTextArabic: String {
        if enhancement.isEnabled && progress >= 0.72 {
            return "نلمّع التفاصيل الحين ✨"
        }
        return "قاعدين نضبط الملف…"
    }

    var processingStageTextEnglish: String {
        if enhancement.isEnabled && progress >= 0.72 {
            return "Enhancing image details…"
        }
        return "Processing the video…"
    }

    func importVideo(url: URL) async {
        isAnalyzing = true
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
        progress = 0
        errorMessage = nil
        validationMessage = nil
        outputInfo = nil
        saveState = .idle
        defer { isProcessing = false }

        do {
            let usesEnhancement = enhancement.isEnabled
            let exportWeight = usesEnhancement ? 0.72 : 1.0

            let baseResult = try await exporter.export(info: info, settings: settings) { [weak self] value in
                Task { @MainActor in
                    self?.progress = min(max(value * exportWeight, 0), exportWeight)
                }
            }

            var finalResult = baseResult

            if usesEnhancement {
                let preferHEVC = settings.codec == .hevc || (
                    settings.codec == .source &&
                    (info.videoCodec.localizedCaseInsensitiveContains("HEVC") || info.videoCodec.localizedCaseInsensitiveContains("H.265"))
                )

                let enhancedURL = try await enhancer.enhance(
                    sourceURL: baseResult.url,
                    settings: enhancement,
                    preferHEVC: preferHEVC
                ) { [weak self] value in
                    Task { @MainActor in
                        self?.progress = min(max(0.72 + value * 0.28, 0.72), 1)
                    }
                }

                if enhancedURL != baseResult.url {
                    try? FileManager.default.removeItem(at: baseResult.url)
                }

                finalResult = ExportOutcome(
                    url: enhancedURL,
                    sourceFPS: baseResult.sourceFPS,
                    outputFPS: baseResult.outputFPS,
                    fpsMode: baseResult.fpsMode,
                    codecLabel: baseResult.codecLabel
                )
            }

            progress = 1
            lastOutcome = finalResult

            do {
                outputInfo = try await analyzer.analyze(url: finalResult.url)
            } catch {
                validationMessage = "تم إنشاء الملف، لكن تعذر التحقق التقني بعد التصدير: \(error.localizedDescription)"
            }

            return finalResult
        } catch {
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
