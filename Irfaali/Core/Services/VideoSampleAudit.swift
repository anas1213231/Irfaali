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
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        guard reader.canAdd(output) else { throw AuditError.cannotRead }
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? AuditError.cannotRead }
        defer { reader.cancelReading() }
        var count = 0
        // Compressed samples can arrive in decode order when B-frames are used.
        // Check uniqueness, not arrival ordering, of presentation timestamps.
        var timestamps = Set<Double>()
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            let pts = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            guard pts.isFinite, timestamps.insert(pts).inserted else { throw AuditError.invalidTimestamps }
            count += CMSampleBufferGetNumSamples(sample)
        }
        guard reader.status == .completed else { throw reader.error ?? AuditError.cannotRead }
        return count
    }
}
