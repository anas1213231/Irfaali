@preconcurrency import AVFoundation
import Foundation
import CoreMedia
import AudioToolbox

struct VideoAnalyzer: Sendable {
    enum AnalysisError: LocalizedError {
        case noVideoTrack

        var errorDescription: String? {
            switch self {
            case .noVideoTrack: return "الملف لا يحتوي على مسار فيديو قابل للتحليل."
            }
        }
    }

    func analyze(url: URL) async throws -> VideoAssetInfo {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else { throw AnalysisError.noVideoTrack }

        async let naturalSizeValue = videoTrack.load(.naturalSize)
        async let transformValue = videoTrack.load(.preferredTransform)
        async let fpsValue = videoTrack.load(.nominalFrameRate)
        async let dataRateValue = videoTrack.load(.estimatedDataRate)
        async let descriptionsValue = videoTrack.load(.formatDescriptions)
        async let timeScaleValue = videoTrack.load(.naturalTimeScale)

        let naturalSize = try await naturalSizeValue
        let transform = try await transformValue
        let fps = Double(try await fpsValue)
        let dataRate = Double(try await dataRateValue)
        let descriptions = try await descriptionsValue
        let timeScale = try await timeScaleValue

        let transformedSize = naturalSize.applying(transform)
        let width = Int(abs(transformedSize.width).rounded())
        let height = Int(abs(transformedSize.height).rounded())

        let audio = try await audioInfo(from: asset)
        let resources = try? url.resourceValues(forKeys: [.fileSizeKey])
        let fileSize = Int64(resources?.fileSize ?? 0)

        return VideoAssetInfo(
            url: url,
            fileName: url.lastPathComponent,
            container: containerName(for: url),
            duration: max(0, duration.seconds),
            fileSizeBytes: fileSize,
            width: width,
            height: height,
            sourceFPS: fps,
            estimatedBitrate: dataRate,
            videoCodec: codecName(descriptions.first),
            dynamicRange: dynamicRangeName(descriptions.first),
            audioCodec: audio.codec,
            audioSampleRate: audio.sampleRate,
            audioChannels: audio.channels,
            trackTimeScale: timeScale
        )
    }

    private func audioInfo(from asset: AVAsset) async throws -> (codec: String?, sampleRate: Double?, channels: Int?) {
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            return (nil, nil, nil)
        }
        let descriptions = try await track.load(.formatDescriptions)
        guard let description = descriptions.first else { return (nil, nil, nil) }

        let codec = codecName(description)
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(description) else {
            return (codec, nil, nil)
        }
        return (codec, asbd.pointee.mSampleRate, Int(asbd.pointee.mChannelsPerFrame))
    }

    private func codecName(_ description: CMFormatDescription?) -> String {
        guard let description else { return "Unknown" }
        let subtype = CMFormatDescriptionGetMediaSubType(description)
        switch subtype {
        case kCMVideoCodecType_H264: return "H.264 / AVC"
        case kCMVideoCodecType_HEVC: return "H.265 / HEVC"
        case kAudioFormatMPEG4AAC: return "AAC"
        case kAudioFormatMPEG4AAC_HE: return "HE-AAC"
        default: return fourCC(subtype)
        }
    }

    private func dynamicRangeName(_ description: CMFormatDescription?) -> String {
        guard let description else { return "Unknown" }
        let text = String(describing: CMFormatDescriptionGetExtensions(description)).uppercased()
        if text.contains("SMPTE_ST_2084") || text.contains("PQ") { return "HDR · PQ" }
        if text.contains("HLG") || text.contains("ITU_R_2100") { return "HDR · HLG" }
        return "SDR"
    }

    private func fourCC(_ value: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ]
        let text = String(bytes: bytes, encoding: .ascii)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
        return text.isEmpty ? "Unknown" : text
    }

    private func containerName(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "mp4", "m4v": return "MP4"
        case "mov": return "MOV"
        case "webm": return "WebM"
        default: return url.pathExtension.uppercased().isEmpty ? "Unknown" : url.pathExtension.uppercased()
        }
    }
}
