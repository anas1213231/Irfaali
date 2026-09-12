import CoreVideo
import Foundation
import Vision

struct OpticalFlowService {
    enum FlowError: LocalizedError {
        case mismatchedDimensions
        case noFlowResult

        var errorDescription: String? {
            switch self {
            case .mismatchedDimensions:
                return "Optical-flow frames must have identical dimensions."
            case .noFlowResult:
                return "Vision did not return an optical-flow buffer."
            }
        }
    }

    /// Generates a real dense motion-vector field between two adjacent video frames.
    /// This is the motion-analysis foundation for genuine frame interpolation; it does
    /// not by itself synthesize or claim a new frame.
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

        let handler = VNImageRequestHandler(cvPixelBuffer: source, options: [:])
        try handler.perform([request])

        guard let flow = request.results?.first?.pixelBuffer else {
            throw FlowError.noFlowResult
        }
        return flow
    }
}
