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
    @Published private(set) var isAnalyzing = false
    @Published private(set) var isProcessing = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var lastOutcome: ExportOutcome?
    @Published private(set) var validationMessage: String?
    @Published private(set) var saveState: SaveState = .idle
    @Published var errorMessage: String?

    private let analyzer = VideoAnalyzer()
    private let exporter = VideoExportService()
    private let photoSaver = PhotoLibrarySaver()

    var canProcess: Bool {
        guard let info else { return false }
        return !settings.needsFrameGeneration(for: info) && !isAnalyzing && !isProcessing
    }

    var needsFrameGeneration: Bool {
        guard let info else { return false }
        return settings.needsFrameGeneration(for: info)
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
        } catch {
            info = nil
            errorMessage = error.localizedDescription
        }
    }

    func applyRecommendedSettings() {
        guard let info else { return }
        settings = VideoProcessingSettings.recommended(for: info)
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
            let result = try await exporter.export(info: info, settings: settings) { [weak self] value in
                Task { @MainActor in
                    self?.progress = min(max(value, 0), 1)
                }
            }

            lastOutcome = result

            do {
                outputInfo = try await analyzer.analyze(url: result.url)
            } catch {
                validationMessage = "تم إنشاء الملف، لكن تعذر التحقق التقني بعد التصدير: \(error.localizedDescription)"
            }

            return result
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
