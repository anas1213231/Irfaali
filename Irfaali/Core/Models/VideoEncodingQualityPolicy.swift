import CoreGraphics
import Foundation

/// Conservative high-quality bitrate policy for final delivery files.
///
/// This does not pretend bitrate alone creates detail. Its job is to keep the
/// encoder from throwing away detail that the restoration/motion pipeline has
/// already produced, especially for 1080p60 and high-motion exports.
enum VideoEncodingQualityPolicy {
    static func targetBitrate(
        size: CGSize,
        fps: Double,
        hevc: Bool,
        sourceBitrate: Double
    ) -> Double {
        let width = max(2, Double(size.width))
        let height = max(2, Double(size.height))
        let cadence = min(max(fps, 1), 240)
        let pixelsPerSecond = width * height * cadence

        // High-quality delivery targets. HEVC needs fewer bits for comparable
        // quality, while H.264 receives a larger budget for motion/detail.
        let bitsPerPixelFrame = hevc ? 0.10 : 0.16
        let contentFloor = pixelsPerSecond * bitsPerPixelFrame

        // Never collapse a healthy source into a visibly weaker encode merely
        // because its geometry is small. At the same time, cap pathological
        // source metadata so one malformed file cannot request absurd bitrates.
        let saneSource = min(max(sourceBitrate, 0), 140_000_000)
        let minimum = hevc ? 3_000_000.0 : 4_000_000.0
        let maximum = 140_000_000.0

        return min(maximum, max(minimum, saneSource, contentFloor))
    }
}
