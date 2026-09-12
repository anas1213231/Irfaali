import CoreVideo
import Foundation
import Vision

struct OpticalFlowService {
    enum FlowError: LocalizedError {
        case mismatchedDimensions
        case noFlowResult
        case unsupportedFlowFormat(OSType)

        var errorDescription: String? {
            switch self {
            case .mismatchedDimensions:
                return "Optical-flow frames must have identical dimensions."
            case .noFlowResult:
                return "Vision did not return an optical-flow buffer."
            case .unsupportedFlowFormat(let format):
                return "Vision returned an unsupported optical-flow pixel format: \(format)."
            }
        }
    }

    /// Generates a dense motion-vector field between two adjacent video frames.
    ///
    /// The output is explicitly requested as two-component 32-bit float so the
    /// motion-warp stage can consume the field directly on the GPU as RG32Float.
    /// This method analyzes motion only; it never duplicates frames or changes FPS.
    func generateFlow(
        from source: CVPixelBuffer,
        to target: CVPixelBuffer,
        accuracy: VNGenerateOpticalFlowRequest.ComputationAccuracy = .high
    ) throws -> CVPixelBuffer {
        guard CVPixelBufferGetWidth(source) == CVPixelBufferGetWidth(target),
              CVPixelBufferGetHeight(source) == CVPixelBufferGetHeight(target) else {
            throw FlowError.mismatchedDimensions
        }

        let request = VNGenerateOpticalFlowRequest(
            targetedCVPixelBuffer: target,
            options: [:]
        )
        request.computationAccuracy = accuracy
        request.keepNetworkOutput = false
        request.outputPixelFormat = kCVPixelFormatType_TwoComponent32Float

        let handler = VNImageRequestHandler(cvPixelBuffer: source, options: [:])
        try handler.perform([request])

        guard let flow = request.results?.first?.pixelBuffer else {
            throw FlowError.noFlowResult
        }

        let format = CVPixelBufferGetPixelFormatType(flow)
        guard format == kCVPixelFormatType_TwoComponent32Float else {
            throw FlowError.unsupportedFlowFormat(format)
        }

        return flow
    }
}
