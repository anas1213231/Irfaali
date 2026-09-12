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

    init(
        createdAt: Date = .now,
        sourceFileName: String,
        outputURL: URL,
        presetName: String,
        width: Int,
        height: Int,
        fps: Double,
        codec: String
    ) {
        self.createdAt = createdAt
        self.sourceFileName = sourceFileName
        self.outputPath = outputURL.path
        self.presetName = presetName
        self.width = width
        self.height = height
        self.fps = fps
        self.codec = codec
    }

    var outputURL: URL { URL(fileURLWithPath: outputPath) }
}
