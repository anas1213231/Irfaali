import CoreVideo
import XCTest
@testable import Irfaali

final class SceneCutDetectorTests: XCTestCase {
    func testSimilarFramesAreNotCuts() throws {
        let first = try makeSolidBGRA(width: 64, height: 64, value: 90)
        let second = try makeSolidBGRA(width: 64, height: 64, value: 100)

        let result = SceneCutDetector().evaluate(previous: first, current: second)

        XCTAssertFalse(result.isCut)
        XCTAssertLessThan(result.score, 0.1)
    }

    func testLargeLuminanceJumpIsCut() throws {
        let first = try makeSolidBGRA(width: 64, height: 64, value: 10)
        let second = try makeSolidBGRA(width: 64, height: 64, value: 245)

        let result = SceneCutDetector().evaluate(previous: first, current: second)

        XCTAssertTrue(result.isCut)
        XCTAssertGreaterThan(result.score, 0.8)
    }

    private func makeSolidBGRA(width: Int, height: Int, value: UInt8) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &buffer
        )

        guard status == kCVReturnSuccess, let buffer else {
            throw NSError(domain: "SceneCutDetectorTests", code: Int(status))
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let base = CVPixelBufferGetBaseAddress(buffer) else {
            throw NSError(domain: "SceneCutDetectorTests", code: -1)
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<height {
            let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width {
                let offset = x * 4
                row[offset] = value
                row[offset + 1] = value
                row[offset + 2] = value
                row[offset + 3] = 255
            }
        }

        return buffer
    }
}
