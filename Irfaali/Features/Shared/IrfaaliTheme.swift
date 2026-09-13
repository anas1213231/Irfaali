import SwiftUI

enum IrfaaliTheme {
    /// The brand palette is intentionally small: deep navy, ice blue and white.
    /// Keeping one accent across controls makes the app feel like one product,
    /// rather than a collection of unrelated cards.
    static let accent = Color(red: 0.72, green: 0.88, blue: 1.00)
    static let accentDeep = Color(red: 0.25, green: 0.48, blue: 0.73)
    static let emerald = Color(red: 0.04, green: 0.15, blue: 0.30)
    static let ink = Color(red: 0.012, green: 0.025, blue: 0.065)
    static let secondaryInk = Color(red: 0.035, green: 0.085, blue: 0.17)
    static let warmWhite = Color(red: 0.985, green: 0.99, blue: 1.00)

    /// The same quiet surface used by the native launch screen hand-off.
    static let launchBackground = LinearGradient(
        colors: [
            Color(red: 0.006, green: 0.014, blue: 0.040),
            Color(red: 0.025, green: 0.090, blue: 0.19),
            Color(red: 0.004, green: 0.010, blue: 0.028)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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

            if preferences.appearance == .pureBlack || preferences.appearance == .pureWhite {
                Color.clear
            } else if isDark {
                RadialGradient(
                    colors: [IrfaaliTheme.emerald.opacity(0.11), .clear],
                    center: .topTrailing,
                    startRadius: 8,
                    endRadius: 360
                )
                .blendMode(.screen)

                RadialGradient(
                    colors: [IrfaaliTheme.accentDeep.opacity(0.10), .clear],
                    center: .bottomLeading,
                    startRadius: 10,
                    endRadius: 300
                )
            } else {
                RadialGradient(
                    colors: [IrfaaliTheme.accent.opacity(0.10), .clear],
                    center: .topTrailing,
                    startRadius: 12,
                    endRadius: 420
                )

                RadialGradient(
                    colors: [Color.white.opacity(0.55), .clear],
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
                colors: [IrfaaliTheme.ink, IrfaaliTheme.secondaryInk, Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .pureWhite:
            Color.white
        case .light:
            LinearGradient(
                colors: [IrfaaliTheme.warmWhite, Color(red: 0.91, green: 0.95, blue: 1.00)],
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
                    colors: [IrfaaliTheme.warmWhite, Color(red: 0.91, green: 0.95, blue: 1.00)],
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
