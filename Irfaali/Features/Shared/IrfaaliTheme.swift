import SwiftUI

enum IrfaaliTheme {
    static let accent = IrfaaliVisual.electricCyan
    static let activeAccent = IrfaaliVisual.electricCyan
    static let accentDeep = IrfaaliVisual.coolBlue

    // Legacy compatibility tokens. New V2 views should prefer semantic system colors.
    static let emerald = Color.black
    static let ink = Color.black
    static let secondaryInk = Color.black
    static let warmWhite = Color.white

    static let launchBackground = LinearGradient(
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                Color.black

                LinearGradient(
                    colors: [
                        Color(red: 0.025, green: 0.034, blue: 0.050),
                        Color.black,
                        Color.black
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .opacity(0.78)
            } else {
                Color(red: 0.972, green: 0.970, blue: 0.963)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.95),
                        Color(red: 0.958, green: 0.962, blue: 0.966),
                        Color(red: 0.972, green: 0.970, blue: 0.963)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
        .animation(
            preferences.animationsEnabled ? .easeInOut(duration: 0.18) : nil,
            value: preferences.appearance
        )
    }
}
