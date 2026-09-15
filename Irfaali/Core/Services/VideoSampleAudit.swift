@preconcurrency import AVFoundation
import Foundation

/// Reads the encoded samples back from disk. Generator counters alone are not proof
/// that those frames survived encoding and subsequent enhancement.
struct VideoSampleAudit {
    enum AuditError: Error { case invalidTrack, cannotRead, invalidTimestamps }

    static func frameCount(url: URL) async throws -> Int {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw AuditError.invalidTrack
        }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw AuditError.cannotRead }
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? AuditError.cannotRead }
        defer { reader.cancelReading() }
        var count = 0
        var previousPTS = -Double.infinity
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            let pts = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            guard pts.isFinite, pts > previousPTS,
                  CMSampleBufferGetImageBuffer(sample) != nil else {
                throw AuditError.invalidTimestamps
            }
            previousPTS = pts
            count += 1
        }
        guard reader.status == .completed else { throw reader.error ?? AuditError.cannotRead }
        return count
    }
}
