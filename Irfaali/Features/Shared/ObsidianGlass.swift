import SwiftUI

// UI-UPGRADE: Reusable visual backing only; never owns interactions or app state.
struct ObsidianGlass: View {
    var cornerRadius: CGFloat = 18
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(baseFill)
            .background {
                if !reduceTransparency {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(colorScheme == .dark ? IrfaaliTheme.ink : Color.white)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [.white.opacity(0.075), .clear, .clear]
                                : [.white.opacity(0.44), .clear, .clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .blendMode(colorScheme == .dark ? .screen : .normal)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [.white.opacity(0.30), .white.opacity(0.05), .white.opacity(0.13)]
                                : [.white.opacity(0.94), .black.opacity(0.055), .white.opacity(0.70)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var baseFill: Color {
        if colorScheme == .dark {
            return IrfaaliTheme.secondaryInk.opacity(reduceTransparency ? 0.96 : 0.54)
        }
        return Color.white.opacity(reduceTransparency ? 0.96 : 0.62)
    }
}

// UI-UPGRADE: A bounded, 30 Hz visual overlay; the real progress and processing model are untouched.
struct IridescentProcessingScanner: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            TimelineView(
                .animation(
                    minimumInterval: 1.0 / 30.0,
                    paused: reduceMotion || !preferences.animationsEnabled || scenePhase != .active
                )
            ) { context in
                let running = !reduceMotion && preferences.animationsEnabled && scenePhase == .active
                let phase = running ? (1 - cos(context.date.timeIntervalSinceReferenceDate * .pi / 2)) / 2 : 0.5
                let y = 12 + max(0, geometry.size.height - 24) * phase

                ZStack(alignment: .top) {
                    if reduceTransparency {
                        Color.black.opacity(0.50)
                    } else {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .opacity(0.46)
                    }

                    Rectangle()
                        .fill(IrfaaliTheme.luminousAccent)
                        .frame(height: 58)
                        .mask(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.15), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .offset(y: y - 29)

                    Capsule()
                        .fill(IrfaaliTheme.luminousAccent)
                        .frame(height: 1.5)
                        .shadow(color: IrfaaliTheme.accent.opacity(0.38), radius: 5)
                        .shadow(color: IrfaaliTheme.accentDeep.opacity(0.22), radius: 10)
                        .padding(.horizontal, 12)
                        .offset(y: y)
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
