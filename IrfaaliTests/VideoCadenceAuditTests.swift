import XCTest
@testable import Irfaali

final class VideoCadenceAuditTests: XCTestCase {
    func testPerfect60FPSTimestampsAreStable() {
        let timestamps = (0..<240).map { Double($0) / 60.0 }
        let differences = Array(repeating: 0.035, count: timestamps.count - 1)

        let report = VideoCadenceAudit.summarize(
            timestamps: timestamps,
            visualDifferences: differences
        )

        XCTAssertEqual(report.estimatedFPS, 60, accuracy: 0.001)
        XCTAssertEqual(report.averageFrameInterval, 1.0 / 60.0, accuracy: 0.000_001)
        XCTAssertLessThan(report.intervalJitterRatio, 0.001)
        XCTAssertTrue(report.hasStableTimestamps)
        XCTAssertEqual(report.duplicateLikeRatio, 0, accuracy: 0.000_001)
    }

    func testRepeatedVisualSignaturesAreReportedWithoutChangingFPSEvidence() {
        let timestamps = (0..<120).map { Double($0) / 60.0 }
        var differences = Array(repeating: 0.028, count: timestamps.count - 1)
        for index in stride(from: 0, to: differences.count, by: 3) {
            differences[index] = 0.0001
        }

        let report = VideoCadenceAudit.summarize(
            timestamps: timestamps,
            visualDifferences: differences
        )

        XCTAssertEqual(report.estimatedFPS, 60, accuracy: 0.001)
        XCTAssertGreaterThan(report.duplicateLikeRatio, 0.30)
        XCTAssertTrue(report.hasStableTimestamps)
    }

    func testLargeTimestampJitterFailsStabilitySignal() {
        var timestamps: [Double] = [0]
        for index in 1..<120 {
            let interval = index.isMultiple(of: 4) ? 0.032 : 0.012
            timestamps.append(timestamps[index - 1] + interval)
        }

        let report = VideoCadenceAudit.summarize(
            timestamps: timestamps,
            visualDifferences: Array(repeating: 0.02, count: timestamps.count - 1)
        )

        XCTAssertGreaterThan(report.intervalJitterRatio, 0.08)
        XCTAssertFalse(report.hasStableTimestamps)
    }

    func testInsufficientSamplesReturnNonPassingReport() {
        let report = VideoCadenceAudit.summarize(
            timestamps: [0],
            visualDifferences: []
        )

        XCTAssertEqual(report.estimatedFPS, 0)
        XCTAssertFalse(report.hasStableTimestamps)
    }
}
