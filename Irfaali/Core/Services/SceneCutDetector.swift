import CoreVideo
import Foundation

/// Lightweight cut detector used by the 2× interpolation path.
///
/// Motion interpolation across a hard edit creates severe ghosting because there is
/// no real motion trajectory between the two shots. We sample a coarse luminance grid
/// from the adjacent BGRA frames and mark large discontinuities as cuts. Cut gaps use
/// an explicitly-counted temporal hold instead of pretending a synthesized frame was
/// produced.
struct SceneCutDetector: Sendable {
    struct Result: Equatable, Sendable {
        let score: Double
        let isCut: Bool
    }

    var threshold: Double = 0.24
    var sampleColumns: Int = 24
    var sampleRows: Int = 24

    func evaluate(previous: CVPixelBuffer, current: CVPixelBuffer) -> Result {
        guard CVPixelBufferGetPixelFormatType(previous) == kCVPixelFormatType_32BGRA,
              CVPixelBufferGetPixelFormatType(current) == kCVPixelFormatType_32BGRA,
              CVPixelBufferGetWidth(previous) == CVPixelBufferGetWidth(current),
              CVPixelBufferGetHeight(previous) == CVPixelBufferGetHeight(current) else {
            return Result(score: 1, isCut: true)
        }

        CVPixelBufferLockBaseAddress(previous, .readOnly)
        CVPixelBufferLockBaseAddress(current, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(current, .readOnly)
            CVPixelBufferUnlockBaseAddress(previous, .readOnly)
        }

        guard let previousBase = CVPixelBufferGetBaseAddress(previous),
              let currentBase = CVPixelBufferGetBaseAddress(current) else {
            return Result(score: 1, isCut: true)
        }

        let width = CVPixelBufferGetWidth(previous)
        let height = CVPixelBufferGetHeight(previous)
        let previousStride = CVPixelBufferGetBytesPerRow(previous)
        let currentStride = CVPixelBufferGetBytesPerRow(current)

        let columns = max(4, min(sampleColumns, width))
        let rows = max(4, min(sampleRows, height))
        let xStep = max(1, width / columns)
        let yStep = max(1, height / rows)

        var differenceSum = 0.0
        var sampleCount = 0

        for y in stride(from: yStep / 2, to: height, by: yStep) {
            let previousRow = previousBase.advanced(by: y * previousStride).assumingMemoryBound(to: UInt8.self)
            let currentRow = currentBase.advanced(by: y * currentStride).assumingMemoryBound(to: UInt8.self)

            for x in stride(from: xStep / 2, to: width, by: xStep) {
                let offset = x * 4

                // BGRA -> perceptual luma approximation. Values are normalized to 0...1.
                let previousLuma = (
                    0.0722 * Double(previousRow[offset]) +
                    0.7152 * Double(previousRow[offset + 1]) +
                    0.2126 * Double(previousRow[offset + 2])
                ) / 255.0

                let currentLuma = (
                    0.0722 * Double(currentRow[offset]) +
                    0.7152 * Double(currentRow[offset + 1]) +
                    0.2126 * Double(currentRow[offset + 2])
                ) / 255.0

                differenceSum += abs(previousLuma - currentLuma)
                sampleCount += 1
            }
        }

        guard sampleCount > 0 else {
            return Result(score: 1, isCut: true)
        }

        let score = differenceSum / Double(sampleCount)
        return Result(score: score, isCut: score >= threshold)
    }
}
