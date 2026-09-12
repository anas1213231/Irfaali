import Foundation

struct VideoAssetInfo: Identifiable, Equatable, Sendable {
    let id = UUID()
    let url: URL
    let fileName: String
    let container: String
    let duration: TimeInterval
    let fileSizeBytes: Int64
    let width: Int
    let height: Int
    let sourceFPS: Double
    let estimatedBitrate: Double
    let videoCodec: String
    let dynamicRange: String
    let audioCodec: String?
    let audioSampleRate: Double?
    let audioChannels: Int?
    let trackTimeScale: Int32

    var estimatedFrameCount: Int? {
        guard duration > 0, sourceFPS > 0 else { return nil }
        return Int((duration * sourceFPS).rounded())
    }
    var isTikTokPostingAPIFPSCompatible: Bool { sourceFPS >= 23 && sourceFPS <= 60 }
    var isTikTokPostingAPIResolutionCompatible: Bool {
        width >= 360 && width <= 4096 && height >= 360 && height <= 4096
    }
}
