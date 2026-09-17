import Foundation
import Metal

struct FrameGenerationReadiness: Equatable, Sendable {
    enum Level: String, Equatable, Sendable {
        case ready
        case caution
        case blocked
    }

    enum ThermalLevel: String, Equatable, Sendable {
        case nominal
        case fair
        case serious
        case critical
    }

    enum Reason: Equatable, Sendable, CustomStringConvertible {
        case unsupportedPlan
        case metalUnavailable
        case simulator
        case lowPowerMode
        case thermalSerious
        case thermalCritical
        case oversizedFrame(width: Int, height: Int)

        var description: String {
            switch self {
            case .unsupportedPlan:
                return "The selected frame-generation ratio is not supported."
            case .metalUnavailable:
                return "Metal GPU processing is unavailable."
            case .simulator:
                return "Simulator results cannot validate real-device frame-generation performance."
            case .lowPowerMode:
                return "Low Power Mode can throttle sustained frame generation."
            case .thermalSerious:
                return "The device is already under serious thermal pressure."
            case .thermalCritical:
                return "The device is under critical thermal pressure."
            case .oversizedFrame(let width, let height):
                return "The processing frame is too large for the v1 on-device 2× path (\(width)×\(height))."
            }
        }
    }

    struct Environment: Equatable, Sendable {
        let metalAvailable: Bool
        let isSimulator: Bool
        let lowPowerModeEnabled: Bool
        let thermalLevel: ThermalLevel

        static func current() -> Environment {
            #if targetEnvironment(simulator)
            // The simulator cannot model a physical iPhone's thermal or low-power
            // state reliably. Keep it as an explicit QA caution without calling APIs
            // that are unavailable in the simulator process.
            return Environment(
                metalAvailable: MTLCreateSystemDefaultDevice() != nil,
                isSimulator: true,
                lowPowerModeEnabled: false,
                thermalLevel: .nominal
            )
            #else
            let processInfo = ProcessInfo.processInfo
            return Environment(
                metalAvailable: MTLCreateSystemDefaultDevice() != nil,
                isSimulator: false,
                lowPowerModeEnabled: processInfo.isLowPowerModeEnabled,
                thermalLevel: FrameGenerationReadiness.currentThermalLevel()
            )
            #endif
        }
    }

    /// Runtime guard for sustained frame generation. A critical state stops
    /// immediately; a serious state must persist long enough to prove it is not
    /// a transient spike. The guard never lowers FPS, bitrate, or optical-flow
    /// quality as a hidden thermal workaround.
    struct RuntimeThermalGuard: Equatable, Sendable {
        enum Action: Equatable, Sendable {
            case continueProcessing
            case stop(ThermalLevel)
        }

        static let seriousGracePeriod: TimeInterval = 5
        private(set) var seriousStartedAt: TimeInterval?

        mutating func evaluate(level: ThermalLevel, uptime: TimeInterval) -> Action {
            switch level {
            case .critical:
                return .stop(.critical)
            case .serious:
                if let seriousStartedAt {
                    if uptime - seriousStartedAt >= Self.seriousGracePeriod {
                        return .stop(.serious)
                    }
                } else {
                    seriousStartedAt = uptime
                }
                return .continueProcessing
            case .nominal, .fair:
                seriousStartedAt = nil
                return .continueProcessing
            }
        }
    }

    let level: Level
    let reasons: [Reason]

    var canStart: Bool { level != .blocked }

    static func currentThermalLevel() -> ThermalLevel {
        #if targetEnvironment(simulator)
        return .nominal
        #else
        return ThermalLevel(ProcessInfo.processInfo.thermalState)
        #endif
    }

    static func evaluate(
        plan: FrameGenerationPlan?,
        width: Int,
        height: Int,
        environment: Environment
    ) -> FrameGenerationReadiness {
        var blocking: [Reason] = []
        var cautions: [Reason] = []

        guard let plan, plan.strategy == .opticalFlow2x else {
            return FrameGenerationReadiness(level: .blocked, reasons: [.unsupportedPlan])
        }

        if !environment.metalAvailable {
            blocking.append(.metalUnavailable)
        }

        switch environment.thermalLevel {
        case .critical:
            blocking.append(.thermalCritical)
        case .serious:
            cautions.append(.thermalSerious)
        case .nominal, .fair:
            break
        }

        // The internal optical-flow path stays inside a 4K-class working set.
        // The public release does not expose this path until physical-device
        // quality acceptance is complete.
        let safeWidth = max(width, 0)
        let safeHeight = max(height, 0)
        let longEdge = max(safeWidth, safeHeight)
        let pixelCount = Int64(safeWidth) * Int64(safeHeight)
        if longEdge > 4096 || pixelCount > 12_000_000 {
            blocking.append(.oversizedFrame(width: safeWidth, height: safeHeight))
        }

        if environment.lowPowerModeEnabled {
            cautions.append(.lowPowerMode)
        }

        if environment.isSimulator {
            cautions.append(.simulator)
        }

        if !blocking.isEmpty {
            return FrameGenerationReadiness(level: .blocked, reasons: blocking + cautions)
        }

        if !cautions.isEmpty {
            return FrameGenerationReadiness(level: .caution, reasons: cautions)
        }

        return FrameGenerationReadiness(level: .ready, reasons: [])
    }
}

#if !targetEnvironment(simulator)
private extension FrameGenerationReadiness.ThermalLevel {
    init(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal:
            self = .nominal
        case .fair:
            self = .fair
        case .serious:
            self = .serious
        case .critical:
            self = .critical
        @unknown default:
            self = .serious
        }
    }
}
#endif
