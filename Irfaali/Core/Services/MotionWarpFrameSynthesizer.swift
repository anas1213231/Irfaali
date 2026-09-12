@preconcurrency import Metal
import CoreImage
import CoreVideo
import Foundation

final class MotionWarpFrameSynthesizer {
    enum SynthesisError: LocalizedError {
        case metalUnavailable
        case cannotCreateCommandQueue
        case missingKernel
        case cannotCreatePipeline(String)
        case mismatchedDimensions
        case invalidFraction
        case cannotCreatePixelBuffer
        case cannotCreateTexture(String)
        case commandEncodingFailed
        case gpuFailed(String)

        var errorDescription: String? {
            switch self {
            case .metalUnavailable:
                return "Metal is not available on this device."
            case .cannotCreateCommandQueue:
                return "Could not create the Metal command queue."
            case .missingKernel:
                return "Irfaali motion-warp Metal kernel is missing."
            case .cannotCreatePipeline(let message):
                return "Could not create the motion-warp pipeline: \(message)"
            case .mismatchedDimensions:
                return "Frame interpolation needs matching frame and flow dimensions."
            case .invalidFraction:
                return "Interpolation fraction must be between 0 and 1."
            case .cannotCreatePixelBuffer:
                return "Could not allocate a frame buffer for interpolation."
            case .cannotCreateTexture(let name):
                return "Could not create Metal texture for \(name)."
            case .commandEncodingFailed:
                return "Could not encode the motion-warp GPU command."
            case .gpuFailed(let message):
                return "Motion-warp GPU processing failed: \(message)"
            }
        }
    }

    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private let ciContext: CIContext
    private var textureCache: CVMetalTextureCache!

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw SynthesisError.metalUnavailable
        }
        guard let queue = device.makeCommandQueue() else {
            throw SynthesisError.cannotCreateCommandQueue
        }
        guard let function = device.makeDefaultLibrary()?.makeFunction(name: "irfaaliMotionWarpInterpolate") else {
            throw SynthesisError.missingKernel
        }

        do {
            self.pipeline = try device.makeComputePipelineState(function: function)
        } catch {
            throw SynthesisError.cannotCreatePipeline(error.localizedDescription)
        }

        self.device = device
        self.queue = queue
        self.ciContext = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])

        let cacheStatus = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &textureCache
        )
        guard cacheStatus == kCVReturnSuccess, textureCache != nil else {
            throw SynthesisError.cannotCreateTexture("texture cache")
        }
    }

    /// Synthesizes one motion-compensated frame between two adjacent frames.
    ///
    /// Forward and backward optical-flow fields are used to warp both images toward
    /// the requested point in time, then an occlusion-aware fallback blends toward
    /// the unwarped images when the two flow directions disagree strongly.
    func synthesize(
        source: CVPixelBuffer,
        target: CVPixelBuffer,
        forwardFlow: CVPixelBuffer,
        backwardFlow: CVPixelBuffer,
        fraction: Double
    ) throws -> CVPixelBuffer {
        guard fraction > 0, fraction < 1 else {
            throw SynthesisError.invalidFraction
        }

        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)

        guard width == CVPixelBufferGetWidth(target),
              height == CVPixelBufferGetHeight(target),
              width == CVPixelBufferGetWidth(forwardFlow),
              height == CVPixelBufferGetHeight(forwardFlow),
              width == CVPixelBufferGetWidth(backwardFlow),
              height == CVPixelBufferGetHeight(backwardFlow) else {
            throw SynthesisError.mismatchedDimensions
        }

        let sourceBGRA = try makeBGRAPixelBuffer(width: width, height: height)
        let targetBGRA = try makeBGRAPixelBuffer(width: width, height: height)
        let output = try makeBGRAPixelBuffer(width: width, height: height)

        ciContext.render(
            CIImage(cvPixelBuffer: source).cropped(to: CGRect(x: 0, y: 0, width: width, height: height)),
            to: sourceBGRA
        )
        ciContext.render(
            CIImage(cvPixelBuffer: target).cropped(to: CGRect(x: 0, y: 0, width: width, height: height)),
            to: targetBGRA
        )

        let sourceTexture = try makeTexture(
            pixelBuffer: sourceBGRA,
            format: .bgra8Unorm,
            width: width,
            height: height,
            name: "source frame"
        )
        let targetTexture = try makeTexture(
            pixelBuffer: targetBGRA,
            format: .bgra8Unorm,
            width: width,
            height: height,
            name: "target frame"
        )
        let forwardTexture = try makeTexture(
            pixelBuffer: forwardFlow,
            format: .rg32Float,
            width: width,
            height: height,
            name: "forward flow"
        )
        let backwardTexture = try makeTexture(
            pixelBuffer: backwardFlow,
            format: .rg32Float,
            width: width,
            height: height,
            name: "backward flow"
        )
        let outputTexture = try makeTexture(
            pixelBuffer: output,
            format: .bgra8Unorm,
            width: width,
            height: height,
            name: "output frame"
        )

        guard let commandBuffer = queue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw SynthesisError.commandEncodingFailed
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(sourceTexture.texture, index: 0)
        encoder.setTexture(targetTexture.texture, index: 1)
        encoder.setTexture(forwardTexture.texture, index: 2)
        encoder.setTexture(backwardTexture.texture, index: 3)
        encoder.setTexture(outputTexture.texture, index: 4)

        var t = Float(fraction)
        encoder.setBytes(&t, length: MemoryLayout<Float>.size, index: 0)

        let threadWidth = pipeline.threadExecutionWidth
        let threadHeight = max(1, pipeline.maxTotalThreadsPerThreadgroup / threadWidth)
        encoder.dispatchThreads(
            MTLSize(width: width, height: height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: threadWidth, height: threadHeight, depth: 1)
        )
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw SynthesisError.gpuFailed(error.localizedDescription)
        }

        CVMetalTextureCacheFlush(textureCache, 0)
        return output
    }

    private func makeBGRAPixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw SynthesisError.cannotCreatePixelBuffer
        }
        return pixelBuffer
    }

    private func makeTexture(
        pixelBuffer: CVPixelBuffer,
        format: MTLPixelFormat,
        width: Int,
        height: Int,
        name: String
    ) throws -> CVMetalTexture {
        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            format,
            width,
            height,
            0,
            &cvTexture
        )

        guard status == kCVReturnSuccess,
              let cvTexture,
              CVMetalTextureGetTexture(cvTexture) != nil else {
            throw SynthesisError.cannotCreateTexture(name)
        }
        return cvTexture
    }
}
