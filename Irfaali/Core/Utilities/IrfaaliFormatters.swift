import Foundation

enum IrfaaliFormatters {
    static let byteCount: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useMB, .useGB]
        return formatter
    }()

    static func duration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        let total = Int(seconds.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    static func fps(_ value: Double) -> String {
        guard value > 0 else { return "Unknown" }
        if abs(value.rounded() - value) < 0.01 { return "\(Int(value.rounded())) fps" }
        return String(format: "%.2f fps", value)
    }

    static func bitrate(_ bitsPerSecond: Double) -> String {
        guard bitsPerSecond > 0 else { return "Unknown" }
        return String(format: "%.2f Mbps", bitsPerSecond / 1_000_000)
    }
}
