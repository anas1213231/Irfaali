@preconcurrency import AVFoundation
import CoreGraphics
import Foundation

struct VideoContentAnalyzer: Sendable {
    enum AnalysisError: LocalizedError {
        case noFrames
        case cannotRenderFrame

        var errorDescription: String? {
            switch self {
            case .noFrames:
                return "تعذر أخذ عينات كافية من الفيديو للتحليل."
            case .cannotRenderFrame:
                return "تعذر تجهيز إحدى لقطات الفيديو للتحليل."
            }
        }
    }

    func analyze(info: VideoAssetInfo) async throws -> VideoAnalysisReport {
        try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()

            let asset = AVURLAsset(url: info.url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 192, height: 192)
            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.12, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.12, preferredTimescale: 600)

            let times = sampleTimes(duration: info.duration)
            var frames: [PixelFrame] = []
            frames.reserveCapacity(times.count)

            for seconds in times {
                try Task.checkCancellation()
                var actualTime = CMTime.zero
                let image = try generator.copyCGImage(
                    at: CMTime(seconds: seconds, preferredTimescale: 600),
                    actualTime: &actualTime
                )
                frames.append(try PixelFrame(image: image))
            }

            guard !frames.isEmpty else { throw AnalysisError.noFrames }

            let averageLuminance = mean(frames.map(\.meanLuminance))
            let luminanceDeviation = mean(frames.map(\.luminanceDeviation))
            let highlights = mean(frames.map(\.highlightClippingRatio))
            let shadows = mean(frames.map(\.shadowClippingRatio))
            let sharpness = mean(frames.map(\.sharpnessScore))
            let noise = mean(frames.map(\.noiseScore))
            let compression = mean(frames.map(\.compressionArtifactScore))
            let saturation = mean(frames.map(\.saturationScore))
            let colorCast = mean(frames.map(\.colorCastScore))

            var motionSamples: [Double] = []
            var sceneChanges = 0
            if frames.count > 1 {
                for index in 1..<frames.count {
                    let difference = frames[index - 1].meanAbsoluteLumaDifference(to: frames[index])
                    motionSamples.append(min(1, difference * 2.8))
                    if difference > 0.23 {
                        sceneChanges += 1
                    }
                }
            }

            return VideoAnalysisReport(
                sampledFrameCount: frames.count,
                averageLuminance: clamp01(averageLuminance),
                luminanceDeviation: clamp01(luminanceDeviation),
                highlightClippingRatio: clamp01(highlights),
                shadowClippingRatio: clamp01(shadows),
                sharpnessScore: clamp01(sharpness),
                noiseScore: clamp01(noise),
                compressionArtifactScore: clamp01(compression),
                saturationScore: clamp01(saturation),
                colorCastScore: clamp01(colorCast),
                motionScore: clamp01(mean(motionSamples)),
                sceneChangeCount: sceneChanges
            )
        }.value
    }

    private static func sampleTimes(duration: TimeInterval) -> [Double] {
        guard duration.isFinite, duration > 0.05 else { return [0] }

        let count: Int
        switch duration {
        case ..<3:
            count = 3
        case ..<15:
            count = 5
        default:
            count = 7
        }

        if count == 1 { return [duration * 0.5] }
        return (0..<count).map { index in
            let fraction = (Double(index) + 0.5) / Double(count)
            return min(max(0, duration * fraction), max(0, duration - 0.03))
        }
    }

    private static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func clamp01(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

private struct PixelFrame {
    let width: Int
    let height: Int
    let luma: [Double]
    let meanLuminance: Double
    let luminanceDeviation: Double
    let highlightClippingRatio: Double
    let shadowClippingRatio: Double
    let sharpnessScore: Double
    let noiseScore: Double
    let compressionArtifactScore: Double
    let saturationScore: Double
    let colorCastScore: Double

    init(image: CGImage) throws {
        let sourceWidth = max(image.width, 1)
        let sourceHeight = max(image.height, 1)
        let maxEdge = 160.0
        let scale = min(1, maxEdge / Double(max(sourceWidth, sourceHeight)))
        width = max(16, Int((Double(sourceWidth) * scale).rounded()))
        height = max(16, Int((Double(sourceHeight) * scale).rounded()))

        let bytesPerRow = width * 4
        var rgba = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        let rendered = rgba.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                return false
            }

            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard rendered else { throw VideoContentAnalyzer.AnalysisError.cannotRenderFrame }

        var lumaValues = [Double](repeating: 0, count: width * height)
        var redTotal = 0.0
        var greenTotal = 0.0
        var blueTotal = 0.0
        var saturationTotal = 0.0
        var highlightCount = 0
        var shadowCount = 0

        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * width + x
                let byteIndex = y * bytesPerRow + x * 4
                let r = Double(rgba[byteIndex]) / 255
                let g = Double(rgba[byteIndex + 1]) / 255
                let b = Double(rgba[byteIndex + 2]) / 255
                let value = 0.2126 * r + 0.7152 * g + 0.0722 * b

                lumaValues[pixelIndex] = value
                redTotal += r
                greenTotal += g
                blueTotal += b
                saturationTotal += max(r, g, b) - min(r, g, b)
                if value >= 0.985 { highlightCount += 1 }
                if value <= 0.025 { shadowCount += 1 }
            }
        }

        luma = lumaValues
        let count = Double(max(width * height, 1))
        let mean = lumaValues.reduce(0, +) / count
        meanLuminance = mean

        let variance = lumaValues.reduce(0) { partial, value in
            let delta = value - mean
            return partial + delta * delta
        } / count
        luminanceDeviation = min(1, sqrt(max(variance, 0)) * 2.2)
        highlightClippingRatio = Double(highlightCount) / count
        shadowClippingRatio = Double(shadowCount) / count
        saturationScore = min(1, saturationTotal / count * 1.6)

        let averageR = redTotal / count
        let averageG = greenTotal / count
        let averageB = blueTotal / count
        colorCastScore = min(1, (max(averageR, averageG, averageB) - min(averageR, averageG, averageB)) * 2.2)

        var gradientTotal = 0.0
        var gradientCount = 0
        var residualTotal = 0.0
        var residualCount = 0
        var blockBoundaryTotal = 0.0
        var blockBoundaryCount = 0
        var ordinaryBoundaryTotal = 0.0
        var ordinaryBoundaryCount = 0

        if width > 2 && height > 2 {
            for y in 1..<(height - 1) {
                for x in 1..<(width - 1) {
                    let index = y * width + x
                    let center = lumaValues[index]
                    let left = lumaValues[index - 1]
                    let right = lumaValues[index + 1]
                    let up = lumaValues[index - width]
                    let down = lumaValues[index + width]

                    gradientTotal += abs(right - left) + abs(down - up)
                    gradientCount += 2

                    let neighborMean = (left + right + up + down) * 0.25
                    residualTotal += abs(center - neighborMean)
                    residualCount += 1

                    if x % 8 == 0 {
                        blockBoundaryTotal += abs(center - left)
                        blockBoundaryCount += 1
                    } else if x % 8 == 4 {
                        ordinaryBoundaryTotal += abs(center - left)
                        ordinaryBoundaryCount += 1
                    }

                    if y % 8 == 0 {
                        blockBoundaryTotal += abs(center - up)
                        blockBoundaryCount += 1
                    } else if y % 8 == 4 {
                        ordinaryBoundaryTotal += abs(center - up)
                        ordinaryBoundaryCount += 1
                    }
                }
            }
        }

        let gradientMean = gradientCount > 0 ? gradientTotal / Double(gradientCount) : 0
        sharpnessScore = min(1, gradientMean * 6.2)

        let residualMean = residualCount > 0 ? residualTotal / Double(residualCount) : 0
        let edgeAdjustedResidual = max(0, residualMean - gradientMean * 0.22)
        noiseScore = min(1, edgeAdjustedResidual * 10.0)

        let blockMean = blockBoundaryCount > 0 ? blockBoundaryTotal / Double(blockBoundaryCount) : 0
        let ordinaryMean = ordinaryBoundaryCount > 0 ? ordinaryBoundaryTotal / Double(ordinaryBoundaryCount) : 0
        let excessBlockiness = max(0, blockMean - ordinaryMean)
        compressionArtifactScore = min(1, excessBlockiness * 14.0)
    }

    func meanAbsoluteLumaDifference(to other: PixelFrame) -> Double {
        guard width == other.width, height == other.height, luma.count == other.luma.count, !luma.isEmpty else {
            return 0
        }

        var total = 0.0
        for index in luma.indices {
            total += abs(luma[index] - other.luma[index])
        }
        return total / Double(luma.count)
    }
}
