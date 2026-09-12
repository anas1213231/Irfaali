import SwiftUI

enum IrfaaliTheme {
    static let accent = Color(red: 0.47, green: 0.95, blue: 0.78)
    static let accentDeep = Color(red: 0.08, green: 0.42, blue: 0.33)
    static let emerald = Color(red: 0.03, green: 0.28, blue: 0.22)
    static let ink = Color(red: 0.012, green: 0.035, blue: 0.03)
    static let secondaryInk = Color(red: 0.04, green: 0.085, blue: 0.073)
    static let warmWhite = Color(red: 0.985, green: 0.99, blue: 0.985)

    // Kept for older views while the design system migrates to ThemeBackground.
    static let background = LinearGradient(
        colors: [ink, secondaryInk, Color.black],
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
            base

            if isDark {
                RadialGradient(
                    colors: [IrfaaliTheme.emerald.opacity(0.42), .clear],
                    center: .topTrailing,
                    startRadius: 8,
                    endRadius: 360
                )
                .blendMode(.screen)

                RadialGradient(
                    colors: [IrfaaliTheme.accentDeep.opacity(0.18), .clear],
                    center: .bottomLeading,
                    startRadius: 10,
                    endRadius: 300
                )
            } else {
                RadialGradient(
                    colors: [IrfaaliTheme.accent.opacity(0.16), .clear],
                    center: .topTrailing,
                    startRadius: 12,
                    endRadius: 420
                )

                RadialGradient(
                    colors: [Color.white.opacity(0.9), .clear],
                    center: .bottomLeading,
                    startRadius: 20,
                    endRadius: 340
                )
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: preferences.animationsEnabled ? 0.38 : 0), value: preferences.appearance)
    }

    @ViewBuilder
    private var base: some View {
        switch preferences.appearance {
        case .pureBlack:
            Color.black
        case .dark:
            LinearGradient(
                colors: [IrfaaliTheme.ink, IrfaaliTheme.secondaryInk, .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .pureWhite:
            Color.white
        case .light:
            LinearGradient(
                colors: [IrfaaliTheme.warmWhite, Color(red: 0.93, green: 0.97, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .system:
            if colorScheme == .dark {
                LinearGradient(
                    colors: [IrfaaliTheme.ink, IrfaaliTheme.secondaryInk, .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [IrfaaliTheme.warmWhite, Color(red: 0.93, green: 0.97, blue: 0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
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
