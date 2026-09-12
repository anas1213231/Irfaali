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
                thermalLevel: ThermalLevel(processInfo.thermalState)
            )
            #endif
        }
    }

    let level: Level
    let reasons: [Reason]

    var canStart: Bool { level != .blocked }

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

        // v1 keeps the on-device optical-flow path inside a 4K-class working set.
        // Users can still pick a 4K target before generation; larger source frames
        // must be downscaled first so Vision + Metal do not create unsafe memory pressure.
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
