import SwiftUI

enum IrfaaliTheme {
    static let accent = IrfaaliVisual.electricCyan
    static let activeAccent = IrfaaliVisual.electricCyan
    static let accentDeep = IrfaaliVisual.coolBlue
    static let emerald = Color.black
    static let ink = Color.black
    static let secondaryInk = Color.black
    static let warmWhite = Color.white

    static let launchBackground = LinearGradient(
        colors: [Color.black, Color.black, Color.black],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let background = LinearGradient(
        colors: [Color.black, Color.black, Color.black],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func titleFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    static func strongFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
}

struct ThemeBackground: View {
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        IrfaaliBackdrop()
            .animation(
                preferences.animationsEnabled ? .easeInOut(duration: 0.24) : nil,
                value: preferences.appearance
            )
    }
}
