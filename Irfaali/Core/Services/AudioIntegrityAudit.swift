@preconcurrency import AVFoundation
import Foundation

/// Verifies that audio actually survives processing instead of relying only on
/// the presence of an audio track in metadata.
struct AudioIntegrityAudit {
    enum AuditError: LocalizedError {
        case cannotReadAudio
        case invalidAudioTimestamps

        var errorDescription: String? {
            switch self {
            case .cannotReadAudio:
                return "The audio samples could not be read from the media file."
            case .invalidAudioTimestamps:
                return "The audio track contains invalid or non-increasing timestamps."
            }
        }
    }

    struct Snapshot: Equatable, Sendable {
        let hasAudio: Bool
        let sampleCount: Int
        let firstPresentationTime: Double?
        let lastPresentationTime: Double?
        let sampleEndTime: Double?
        let trackStartTime: Double?
        let trackDuration: Double?

        static let noAudio = Snapshot(
            hasAudio: false,
            sampleCount: 0,
            firstPresentationTime: nil,
            lastPresentationTime: nil,
            sampleEndTime: nil,
            trackStartTime: nil,
            trackDuration: nil
        )
    }

    struct Report: Equatable, Sendable {
        let source: Snapshot
        let output: Snapshot
        let durationDelta: Double
        let startDelta: Double
        let endDelta: Double

        var passed: Bool {
            Self.mismatch(source: source, output: output) == nil
        }

        var mismatchReason: String? {
            Self.mismatch(source: source, output: output)
        }

        private static func mismatch(source: Snapshot, output: Snapshot) -> String? {
            guard source.hasAudio else { return nil }
            guard output.hasAudio else { return "The source audio track is missing from the output." }
            guard output.sampleCount > 0 else { return "The output audio track contains no encoded audio samples." }

            if let sourceDuration = source.trackDuration,
               let outputDuration = output.trackDuration {
                let tolerance = max(0.25, sourceDuration * 0.02)
                if abs(outputDuration - sourceDuration) > tolerance {
                    return String(
                        format: "Audio duration changed too much (source %.3fs, output %.3fs).",
                        sourceDuration,
                        outputDuration
                    )
                }
            }

            if let sourceStart = source.firstPresentationTime,
               let outputStart = output.firstPresentationTime,
               abs(outputStart - sourceStart) > 0.25 {
                return String(
                    format: "Audio start timing shifted too much (source %.3fs, output %.3fs).",
                    sourceStart,
                    outputStart
                )
            }

            if let sourceEnd = source.sampleEndTime,
               let outputEnd = output.sampleEndTime {
                let tolerance = max(0.30, abs(sourceEnd) * 0.02)
                if abs(outputEnd - sourceEnd) > tolerance {
                    return String(
                        format: "Audio end timing shifted too much (source %.3fs, output %.3fs).",
                        sourceEnd,
                        outputEnd
                    )
                }
            }

            return nil
        }
    }

    static func verify(sourceURL: URL, outputURL: URL) async throws -> Report {
        async let sourceSnapshot = inspect(url: sourceURL)
        async let outputSnapshot = inspect(url: outputURL)

        let source = try await sourceSnapshot
        let output = try await outputSnapshot

        return Report(
            source: source,
            output: output,
            durationDelta: delta(source.trackDuration, output.trackDuration),
            startDelta: delta(source.firstPresentationTime, output.firstPresentationTime),
            endDelta: delta(source.sampleEndTime, output.sampleEndTime)
        )
    }

    static func inspect(url: URL) async throws -> Snapshot {
        try await Task.detached(priority: .utility) {
            try Task.checkCancellation()

            let asset = AVURLAsset(url: url)
            guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
                return .noAudio
            }

            let timeRange = try await track.load(.timeRange)
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
            output.alwaysCopiesSampleData = false

            guard reader.canAdd(output) else { throw AuditError.cannotReadAudio }
            reader.add(output)
            guard reader.startReading() else { throw reader.error ?? AuditError.cannotReadAudio }
            defer { reader.cancelReading() }

            var sampleCount = 0
            var firstPTS: Double?
            var lastPTS: Double?
            var lastEnd: Double?
            var previousPTS = -Double.infinity

            while let sample = output.copyNextSampleBuffer() {
                try Task.checkCancellation()

                let pts = CMSampleBufferGetPresentationTimeStamp(sample).seconds
                guard pts.isFinite, pts >= previousPTS else {
                    throw AuditError.invalidAudioTimestamps
                }

                let duration = CMSampleBufferGetDuration(sample).seconds
                let safeDuration = duration.isFinite && duration > 0 ? duration : 0

                if firstPTS == nil { firstPTS = pts }
                lastPTS = pts
                lastEnd = pts + safeDuration
                previousPTS = pts
                sampleCount += 1
            }

            guard reader.status == .completed else {
                throw reader.error ?? AuditError.cannotReadAudio
            }

            return Snapshot(
                hasAudio: true,
                sampleCount: sampleCount,
                firstPresentationTime: firstPTS,
                lastPresentationTime: lastPTS,
                sampleEndTime: lastEnd,
                trackStartTime: timeRange.start.seconds.isFinite ? timeRange.start.seconds : nil,
                trackDuration: timeRange.duration.seconds.isFinite ? timeRange.duration.seconds : nil
            )
        }.value
    }

    private static func delta(_ lhs: Double?, _ rhs: Double?) -> Double {
        guard let lhs, let rhs else { return 0 }
        return abs(lhs - rhs)
    }
}
