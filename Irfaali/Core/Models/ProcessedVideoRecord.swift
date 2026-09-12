import Foundation
import SwiftData

@Model
final class ProcessedVideoRecord {
    var createdAt: Date
    var sourceFileName: String
    var outputPath: String
    var presetName: String
    var width: Int
    var height: Int
    var fps: Double
    var codec: String
    var duration: Double = 0
    var fileSizeBytes: Int64 = 0
    var estimatedBitrate: Double = 0

    init(
        createdAt: Date = .now,
        sourceFileName: String,
        outputURL: URL,
        presetName: String,
        width: Int,
        height: Int,
        fps: Double,
        codec: String,
        duration: Double = 0,
        fileSizeBytes: Int64 = 0,
        estimatedBitrate: Double = 0
    ) {
        self.createdAt = createdAt
        self.sourceFileName = sourceFileName
        self.outputPath = outputURL.path
        self.presetName = presetName
        self.width = width
        self.height = height
        self.fps = fps
        self.codec = codec
        self.duration = duration
        self.fileSizeBytes = fileSizeBytes
        self.estimatedBitrate = estimatedBitrate
    }

    var outputURL: URL { URL(fileURLWithPath: outputPath) }
    var outputExists: Bool { FileManager.default.fileExists(atPath: outputPath) }
}
