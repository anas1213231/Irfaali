import Foundation

@MainActor
final class StudioViewModel: ObservableObject {
    @Published private(set) var info: VideoAssetInfo?
    @Published var selectedPreset: OptimizationPreset = .tiktok
    @Published private(set) var isAnalyzing = false
    @Published private(set) var isProcessing = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var lastOutcome: ExportOutcome?
    @Published var errorMessage: String?

    private let analyzer = VideoAnalyzer()
    private let exporter = VideoExportService()

    func importVideo(url: URL) async {
        isAnalyzing = true
        errorMessage = nil
        lastOutcome = nil
        defer { isAnalyzing = false }
        do {
            info = try await analyzer.analyze(url: url)
        } catch {
            info = nil
            errorMessage = error.localizedDescription
        }
    }

    func process() async -> ExportOutcome? {
        guard let info else { return nil }
        isProcessing = true
        progress = 0
        errorMessage = nil
        defer { isProcessing = false }
        do {
            let result = try await exporter.export(info: info, preset: selectedPreset) { [weak self] value in
                Task { @MainActor in self?.progress = min(max(value, 0), 1) }
            }
            lastOutcome = result
            return result
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
