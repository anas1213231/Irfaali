import SwiftUI

enum IrfaaliTheme {
    static let accent = Color(red: 0.47, green: 0.95, blue: 0.78)
    static let emerald = Color(red: 0.03, green: 0.28, blue: 0.22)
    static let ink = Color(red: 0.02, green: 0.055, blue: 0.05)
    static let secondaryInk = Color(red: 0.055, green: 0.10, blue: 0.09)

    static let background = LinearGradient(
        colors: [ink, secondaryInk, Color.black],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
