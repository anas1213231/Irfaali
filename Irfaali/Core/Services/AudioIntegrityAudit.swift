@preconcurrency import AVFoundation
import AudioToolbox
import Foundation

/// Verifies that audio actually survives processing instead of relying only on
/// the presence of an audio track in metadata.
///
/// The audit is intentionally bounded for performance: it validates decoded
/// samples near the beginning and end of the track and uses the real track time
/// range for duration evidence. Long videos are not rescanned end-to-end merely
/// to prove audio preservation.
struct AudioIntegrityAudit {
    enum AuditError: LocalizedError {
        case cannotReadAudio
        case invalidAudioTimestamps

        var errorDescription: String? {
            switch self {
            case .cannotReadAudio:
                return "The audio samples could not be read from the media file."
            case .invalidAudioTimestamps:
                return "The audio track contains invalid timestamps."
            }
        }
    }

    struct Snapshot: Equatable, Sendable {
        let hasAudio: Bool
        /// Number of samples inspected in the bounded verification windows.
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
        let avStartSyncDelta: Double?
        let avEndSyncDelta: Double?

        init(
            source: Snapshot,
            output: Snapshot,
            durationDelta: Double,
            startDelta: Double,
            endDelta: Double,
            avStartSyncDelta: Double? = nil,
            avEndSyncDelta: Double? = nil
        ) {
            self.source = source
            self.output = output
            self.durationDelta = durationDelta
            self.startDelta = startDelta
            self.endDelta = endDelta
            self.avStartSyncDelta = avStartSyncDelta
            self.avEndSyncDelta = avEndSyncDelta
        }

        var passed: Bool {
            Self.mismatch(
                source: source,
                output: output,
                avStartSyncDelta: avStartSyncDelta,
                avEndSyncDelta: avEndSyncDelta
            ) == nil
        }

        var mismatchReason: String? {
            Self.mismatch(
                source: source,
                output: output,
                avStartSyncDelta: avStartSyncDelta,
                avEndSyncDelta: avEndSyncDelta
            )
        }

        private static func mismatch(
            source: Snapshot,
            output: Snapshot,
            avStartSyncDelta: Double?,
            avEndSyncDelta: Double?
        ) -> String? {
            guard source.hasAudio else { return nil }
            guard output.hasAudio else { return "The source audio track is missing from the output." }
            guard output.sampleCount > 0 else { return "The output audio track contains no decodable audio samples." }

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

            // Preserve the source's intentional audio/video offset instead of
            // assuming every valid file begins both tracks at absolute time zero.
            // The thresholds match the integration-level A/V timing contract.
            if let avStartSyncDelta {
                if avStartSyncDelta > 0.05 {
                    return String(
                        format: "Audio/video start sync shifted by %.3fs.",
                        avStartSyncDelta
                    )
                }
            } else if let sourceStart = source.firstPresentationTime,
                      let outputStart = output.firstPresentationTime,
                      abs(outputStart - sourceStart) > 0.25 {
                return String(
                    format: "Audio start timing shifted too much (source %.3fs, output %.3fs).",
                    sourceStart,
                    outputStart
                )
            }

            if let avEndSyncDelta {
                if avEndSyncDelta > 0.08 {
                    return String(
                        format: "Audio/video end sync shifted by %.3fs.",
                        avEndSyncDelta
                    )
                }
            } else if let sourceEnd = source.sampleEndTime,
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
        async let sourceSync = inspectAVSyncOffsets(url: sourceURL)
        async let outputSync = inspectAVSyncOffsets(url: outputURL)

        let source = try await sourceSnapshot
        let output = try await outputSnapshot
        let sourceOffsets = try await sourceSync
        let outputOffsets = try await outputSync

        return Report(
            source: source,
            output: output,
            durationDelta: delta(source.trackDuration, output.trackDuration),
            startDelta: delta(source.firstPresentationTime, output.firstPresentationTime),
            endDelta: delta(source.sampleEndTime, output.sampleEndTime),
            avStartSyncDelta: optionalDelta(sourceOffsets.start, outputOffsets.start),
            avEndSyncDelta: optionalDelta(sourceOffsets.end, outputOffsets.end)
        )
    }

    static func inspect(url: URL) async throws -> Snapshot {
        try await Task.detached(priority: .utility) {
            try Task.checkCancellation()

            let asset = AVURLAsset(url: url)
            guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
                return .noAudio
            }

            let trackRange = try await track.load(.timeRange)
            let start = trackRange.start
            let duration = trackRange.duration
            let durationSeconds = duration.seconds

            guard durationSeconds.isFinite, durationSeconds > 0 else {
                throw AuditError.cannotReadAudio
            }

            let evidenceWindow = CMTime(seconds: min(1.0, durationSeconds), preferredTimescale: 48_000)
            let startRange = CMTimeRange(start: start, duration: evidenceWindow)
            let startEvidence = try inspectWindow(asset: asset, track: track, range: startRange)

            let endEvidence: WindowEvidence
            if durationSeconds <= 1.25 {
                endEvidence = startEvidence
            } else {
                let trackEnd = CMTimeAdd(start, duration)
                let tailStart = CMTimeSubtract(trackEnd, evidenceWindow)
                endEvidence = try inspectWindow(
                    asset: asset,
                    track: track,
                    range: CMTimeRange(start: tailStart, duration: evidenceWindow)
                )
            }

            return Snapshot(
                hasAudio: true,
                sampleCount: startEvidence.sampleCount + (durationSeconds <= 1.25 ? 0 : endEvidence.sampleCount),
                firstPresentationTime: startEvidence.firstPTS,
                lastPresentationTime: endEvidence.lastPTS,
                sampleEndTime: endEvidence.lastEnd,
                trackStartTime: start.seconds.isFinite ? start.seconds : nil,
                trackDuration: durationSeconds
            )
        }.value
    }

    private struct WindowEvidence {
        let sampleCount: Int
        let firstPTS: Double?
        let lastPTS: Double?
        let lastEnd: Double?
    }

    private struct AVSyncOffsets: Sendable {
        let start: Double?
        let end: Double?

        static let unavailable = AVSyncOffsets(start: nil, end: nil)
    }

    private static func inspectAVSyncOffsets(url: URL) async throws -> AVSyncOffsets {
        let asset = AVURLAsset(url: url)
        async let audioTracks = asset.loadTracks(withMediaType: .audio)
        async let videoTracks = asset.loadTracks(withMediaType: .video)

        let audios = try await audioTracks
        let videos = try await videoTracks
        guard let audio = audios.first, let video = videos.first else {
            return .unavailable
        }

        async let audioRangeValue = audio.load(.timeRange)
        async let videoRangeValue = video.load(.timeRange)
        let audioRange = try await audioRangeValue
        let videoRange = try await videoRangeValue

        let audioStart = audioRange.start.seconds
        let videoStart = videoRange.start.seconds
        let audioEnd = CMTimeRangeGetEnd(audioRange).seconds
        let videoEnd = CMTimeRangeGetEnd(videoRange).seconds

        guard audioStart.isFinite,
              videoStart.isFinite,
              audioEnd.isFinite,
              videoEnd.isFinite else {
            return .unavailable
        }

        return AVSyncOffsets(
            start: audioStart - videoStart,
            end: audioEnd - videoEnd
        )
    }

    private static func inspectWindow(
        asset: AVAsset,
        track: AVAssetTrack,
        range: CMTimeRange
    ) throws -> WindowEvidence {
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = range

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false

        guard reader.canAdd(output) else { throw AuditError.cannotReadAudio }
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? AuditError.cannotReadAudio }
        defer { reader.cancelReading() }

        var count = 0
        var firstPTS: Double?
        var lastPTS: Double?
        var lastEnd: Double?

        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()

            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sample)
            guard presentationTime.isValid, presentationTime.isNumeric else {
                throw AuditError.invalidAudioTimestamps
            }

            let pts = presentationTime.seconds
            guard pts.isFinite else { throw AuditError.invalidAudioTimestamps }
            let sampleDuration = CMSampleBufferGetDuration(sample).seconds
            let safeDuration = sampleDuration.isFinite && sampleDuration > 0 ? sampleDuration : 0

            // Audit decoded PCM rather than compressed AAC packet metadata. This
            // proves the audio is actually decodable while avoiding codec priming
            // or packet reordering from producing false corruption failures.
            firstPTS = min(firstPTS ?? Double.infinity, pts)
            lastPTS = max(lastPTS ?? -Double.infinity, pts)
            lastEnd = max(lastEnd ?? -Double.infinity, pts + safeDuration)
            count += 1
        }

        guard reader.status == .completed else {
            throw reader.error ?? AuditError.cannotReadAudio
        }

        return WindowEvidence(
            sampleCount: count,
            firstPTS: firstPTS,
            lastPTS: lastPTS,
            lastEnd: lastEnd
        )
    }

    private static func delta(_ lhs: Double?, _ rhs: Double?) -> Double {
        guard let lhs, let rhs else { return 0 }
        return abs(lhs - rhs)
    }

    private static func optionalDelta(_ lhs: Double?, _ rhs: Double?) -> Double? {
        guard let lhs, let rhs else { return nil }
        return abs(lhs - rhs)
    }
}
