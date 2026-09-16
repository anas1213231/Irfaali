@preconcurrency import AVFoundation
import CoreVideo
import Foundation

/// Evidence-oriented cadence inspection for exported media.
///
/// Nominal FPS metadata is not enough to prove a high-frame-rate export. This
/// audit reads encoded samples back from disk, checks presentation timestamps,
/// and compares lightweight luminance signatures between consecutive frames.
/// The visual duplicate ratio is diagnostic evidence only: a genuinely static
/// shot can legitimately contain many nearly identical frames.
struct VideoCadenceAudit {
    enum AuditError: LocalizedError {
        case missingVideoTrack
        case cannotRead
        case invalidTimestamp
        case missingPixelBuffer

        var errorDescription: String? {
            switch self {
            case .missingVideoTrack:
                return "No video track is available for cadence verification."
            case .cannotRead:
                return "The encoded video samples could not be read back."
            case .invalidTimestamp:
                return "The encoded video contains invalid or non-increasing presentation timestamps."
            case .missingPixelBuffer:
                return "A decoded video sample did not contain a usable image buffer."
            }
        }
    }

    struct Report: Equatable, Sendable {
        let inspectedFrameCount: Int
        let estimatedFPS: Double
        let averageFrameInterval: Double
        let maximumIntervalDeviation: Double
        let intervalJitterRatio: Double
        let duplicateLikeRatio: Double
        let averageVisualDifference: Double

        var hasStableTimestamps: Bool {
            intervalJitterRatio <= 0.08 && maximumIntervalDeviation <= max(0.004, averageFrameInterval * 0.25)
        }
    }

    static func audit(url: URL, maximumFrames: Int = 360) async throws -> Report {
        let worker = Task.detached(priority: .utility) {
            try Task.checkCancellation()

            let asset = AVURLAsset(url: url)
            guard let track = try await asset.loadTracks(withMediaType: .video).first else {
                throw AuditError.missingVideoTrack
            }

            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(
                track: track,
                outputSettings: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
            )
            output.alwaysCopiesSampleData = false

            guard reader.canAdd(output) else { throw AuditError.cannotRead }
            reader.add(output)
            guard reader.startReading() else { throw reader.error ?? AuditError.cannotRead }
            defer { reader.cancelReading() }

            var timestamps: [Double] = []
            var visualDifferences: [Double] = []
            var previousSignature: [Double]?
            let frameLimit = max(2, maximumFrames)

            while timestamps.count < frameLimit, let sample = output.copyNextSampleBuffer() {
                try Task.checkCancellation()

                let pts = CMSampleBufferGetPresentationTimeStamp(sample).seconds
                guard pts.isFinite else { throw AuditError.invalidTimestamp }
                if let previous = timestamps.last, pts <= previous {
                    throw AuditError.invalidTimestamp
                }

                guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else {
                    throw AuditError.missingPixelBuffer
                }

                let signature = frameSignature(pixelBuffer)
                if let previousSignature {
                    visualDifferences.append(meanAbsoluteDifference(previousSignature, signature))
                }
                previousSignature = signature
                timestamps.append(pts)
            }

            guard timestamps.count >= 2 else {
                throw reader.error ?? AuditError.cannotRead
            }

            if reader.status == .failed {
                throw reader.error ?? AuditError.cannotRead
            }

            return summarize(timestamps: timestamps, visualDifferences: visualDifferences)
        }

        return try await withTaskCancellationHandler(operation: {
            try await worker.value
        }, onCancel: {
            worker.cancel()
        })
    }

    static func summarize(timestamps: [Double], visualDifferences: [Double]) -> Report {
        guard timestamps.count >= 2 else {
            return Report(
                inspectedFrameCount: timestamps.count,
                estimatedFPS: 0,
                averageFrameInterval: 0,
                maximumIntervalDeviation: 0,
                intervalJitterRatio: 1,
                duplicateLikeRatio: 0,
                averageVisualDifference: 0
            )
        }

        let deltas = zip(timestamps.dropFirst(), timestamps).map { current, previous in
            max(0, current - previous)
        }
        let averageInterval = mean(deltas)
        let duration = max(0.000_001, timestamps.last! - timestamps.first!)
        let estimatedFPS = Double(timestamps.count - 1) / duration
        let maximumDeviation = deltas.map { abs($0 - averageInterval) }.max() ?? 0

        let variance = deltas.reduce(0) { partial, value in
            let delta = value - averageInterval
            return partial + delta * delta
        } / Double(max(deltas.count, 1))
        let standardDeviation = sqrt(max(0, variance))
        let jitterRatio = averageInterval > 0 ? standardDeviation / averageInterval : 1

        let validVisualDifferences = visualDifferences.filter(\.isFinite)
        let averageVisualDifference = mean(validVisualDifferences)
        let duplicateThreshold = 0.0025
        let duplicateCount = validVisualDifferences.filter { $0 <= duplicateThreshold }.count
        let duplicateLikeRatio = validVisualDifferences.isEmpty
            ? 0
            : Double(duplicateCount) / Double(validVisualDifferences.count)

        return Report(
            inspectedFrameCount: timestamps.count,
            estimatedFPS: estimatedFPS,
            averageFrameInterval: averageInterval,
            maximumIntervalDeviation: maximumDeviation,
            intervalJitterRatio: jitterRatio,
            duplicateLikeRatio: duplicateLikeRatio,
            averageVisualDifference: averageVisualDifference
        )
    }

    private static func frameSignature(_ pixelBuffer: CVPixelBuffer) -> [Double] {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return [] }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard width > 0, height > 0, bytesPerRow >= width * 4 else { return [] }

        let pointer = baseAddress.assumingMemoryBound(to: UInt8.self)
        let columns = 12
        let rows = 8
        var signature: [Double] = []
        signature.reserveCapacity(columns * rows)

        for row in 0..<rows {
            let y = min(height - 1, (row * height + height / (rows * 2)) / rows)
            for column in 0..<columns {
                let x = min(width - 1, (column * width + width / (columns * 2)) / columns)
                let offset = y * bytesPerRow + x * 4
                let b = Double(pointer[offset]) / 255
                let g = Double(pointer[offset + 1]) / 255
                let r = Double(pointer[offset + 2]) / 255
                signature.append(0.2126 * r + 0.7152 * g + 0.0722 * b)
            }
        }

        return signature
    }

    private static func meanAbsoluteDifference(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }
        var total = 0.0
        for index in lhs.indices {
            total += abs(lhs[index] - rhs[index])
        }
        return total / Double(lhs.count)
    }

    private static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}
