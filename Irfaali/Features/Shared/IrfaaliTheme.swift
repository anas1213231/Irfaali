import SwiftUI

enum IrfaaliTheme {
    // UI-UPGRADE: Neutral obsidian surfaces; color is reserved for interactive accents.
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.30, green: 0.86, blue: 0.94, alpha: 1)
            : UIColor(red: 0.05, green: 0.37, blue: 0.44, alpha: 1)
    })
    static let accentDeep = Color(red: 0.43, green: 0.27, blue: 0.82)
    static let emerald = Color(red: 0.055, green: 0.055, blue: 0.062)
    static let ink = Color(red: 0.012, green: 0.012, blue: 0.016)
    static let secondaryInk = Color(red: 0.035, green: 0.035, blue: 0.044)
    static let warmWhite = Color(red: 0.985, green: 0.99, blue: 1.00)

    static let primaryText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : UIColor(white: 0.08, alpha: 1)
    })
    static let silver = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.73, green: 0.75, blue: 0.79, alpha: 1)
            : UIColor(red: 0.32, green: 0.34, blue: 0.39, alpha: 1)
    })
    static let luminousAccent = LinearGradient(
        colors: [Color(red: 0.26, green: 0.88, blue: 0.96), Color(red: 0.47, green: 0.30, blue: 0.89)],
        startPoint: .leading, endPoint: .trailing
    )
    // Dark jewel tones keep white button labels readable; brighter color stays at the edge.
    static let primaryButtonFill = LinearGradient(
        colors: [Color(red: 0.055, green: 0.31, blue: 0.39), Color(red: 0.24, green: 0.12, blue: 0.46)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

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
                    colors: [Color.white.opacity(0.035), .clear],
                    center: .topTrailing,
                    startRadius: 8,
                    endRadius: 360
                )
                .blendMode(.screen)

                RadialGradient(
                    colors: [IrfaaliTheme.secondaryInk.opacity(0.30), .clear],
                    center: .bottomLeading,
                    startRadius: 10,
                    endRadius: 300
                )
            } else {
                RadialGradient(
                    colors: [Color.black.opacity(0.035), .clear],
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
        .animation(.easeInOut(duration: preferences.animationsEnabled ? 0.15 : 0), value: preferences.appearance)
    }

    @ViewBuilder
    private var base: some View {
        switch preferences.appearance {
        case .pureBlack:
            Color.black
        case .dark:
            LinearGradient(
                colors: [Color.black, IrfaaliTheme.ink, Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .pureWhite:
            Color.white
        case .light:
            LinearGradient(
                colors: [IrfaaliTheme.warmWhite, Color(red: 0.93, green: 0.94, blue: 0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .system:
            if colorScheme == .dark {
                LinearGradient(
                    colors: [Color.black, IrfaaliTheme.ink, .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [IrfaaliTheme.warmWhite, Color(red: 0.93, green: 0.94, blue: 0.96)],
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
