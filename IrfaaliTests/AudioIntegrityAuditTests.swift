import XCTest
@testable import Irfaali

final class AudioIntegrityAuditTests: XCTestCase {
    func testNoSourceAudioPassesWithoutInventingRequirement() {
        let report = AudioIntegrityAudit.Report(
            source: .noAudio,
            output: .noAudio,
            durationDelta: 0,
            startDelta: 0,
            endDelta: 0
        )

        XCTAssertTrue(report.passed)
        XCTAssertNil(report.mismatchReason)
    }

    func testMissingOutputAudioFails() {
        let source = snapshot(duration: 10, firstPTS: 0, end: 10, samples: 480)
        let report = AudioIntegrityAudit.Report(
            source: source,
            output: .noAudio,
            durationDelta: 10,
            startDelta: 0,
            endDelta: 10
        )

        XCTAssertFalse(report.passed)
        XCTAssertNotNil(report.mismatchReason)
    }

    func testSmallAACTimingDriftPasses() {
        let source = snapshot(duration: 10, firstPTS: 0, end: 10, samples: 480)
        let output = snapshot(duration: 9.94, firstPTS: 0.021, end: 9.96, samples: 477)
        let report = AudioIntegrityAudit.Report(
            source: source,
            output: output,
            durationDelta: 0.06,
            startDelta: 0.021,
            endDelta: 0.04
        )

        XCTAssertTrue(report.passed)
    }

    func testLargeDurationLossFails() {
        let source = snapshot(duration: 12, firstPTS: 0, end: 12, samples: 576)
        let output = snapshot(duration: 9.2, firstPTS: 0, end: 9.2, samples: 441)
        let report = AudioIntegrityAudit.Report(
            source: source,
            output: output,
            durationDelta: 2.8,
            startDelta: 0,
            endDelta: 2.8
        )

        XCTAssertFalse(report.passed)
    }

    func testLargeStartShiftFails() {
        let source = snapshot(duration: 8, firstPTS: 0, end: 8, samples: 384)
        let output = snapshot(duration: 8, firstPTS: 0.5, end: 8.5, samples: 384)
        let report = AudioIntegrityAudit.Report(
            source: source,
            output: output,
            durationDelta: 0,
            startDelta: 0.5,
            endDelta: 0.5
        )

        XCTAssertFalse(report.passed)
    }

    private func snapshot(
        duration: Double,
        firstPTS: Double,
        end: Double,
        samples: Int
    ) -> AudioIntegrityAudit.Snapshot {
        AudioIntegrityAudit.Snapshot(
            hasAudio: true,
            sampleCount: samples,
            firstPresentationTime: firstPTS,
            lastPresentationTime: max(firstPTS, end - 0.021),
            sampleEndTime: end,
            trackStartTime: firstPTS,
            trackDuration: duration
        )
    }
}
