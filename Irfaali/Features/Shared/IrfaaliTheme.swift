import SwiftUI

enum IrfaaliTheme {
    /// Neutral chrome stays white; color is reserved for active sliders and the main process action.
    static let accent = Color.white.opacity(0.96)
    static let activeAccent = Color(red: 0.26, green: 0.70, blue: 0.92)
    static let accentDeep = Color(red: 0.16, green: 0.42, blue: 0.68)
    static let emerald = Color.black
    static let ink = Color.black
    static let secondaryInk = Color.black
    static let warmWhite = Color.white

    /// The native launch hand-off remains visually quiet and dark.
    static let launchBackground = LinearGradient(
        colors: [Color.black, Color.black, Color.black],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Kept for older views while the design system migrates to ThemeBackground.
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Color.black
            .ignoresSafeArea()
            .animation(.easeInOut(duration: preferences.animationsEnabled ? 0.38 : 0), value: preferences.appearance)
    }

    @ViewBuilder
    private var base: some View {
        switch preferences.appearance {
        case .pureBlack:
            Color.black
        case .dark:
            Color.black
        case .pureWhite:
            Color.black
        case .light:
            Color.black
        case .system:
            Color.black
        }
    }

    private var isDark: Bool {
        switch preferences.appearance {
        case .pureBlack, .dark:
            true
        case .light, .pureWhite:
            false
        case .system:
            colorScheme == .dark
        }
    }
}
