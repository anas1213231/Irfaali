import SwiftUI

// UI-UPGRADE: Presentation-only feedback; existing button actions remain untouched.
struct PremiumPressFeedback: ViewModifier {
    let isPressed: Bool
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && isEnabled && preferences.animationsEnabled && !reduceMotion ? 0.95 : 1)
            .animation(
                preferences.animationsEnabled && !reduceMotion
                    ? (isPressed ? .easeOut(duration: 0.12) : .spring(response: 0.36, dampingFraction: 0.62))
                    : nil,
                value: isPressed
            )
            .sensoryFeedback(.impact(weight: .light), trigger: isPressed) { old, new in
                !old && new && isEnabled && preferences.hapticsEnabled
            }
    }
}

struct PremiumInteractiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(PremiumPressFeedback(isPressed: configuration.isPressed))
    }
}

// UI-UPGRADE: Animate the existing tab subtree without changing its identity or routing.
struct PremiumTabEntrance: ViewModifier {
    let isSelected: Bool
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 10)
            .onAppear { reveal() }
            .onChange(of: isSelected) { _, selected in
                if selected { reveal() } else { visible = false }
            }
    }

    private func reveal() {
        guard isSelected else { return }
        withAnimation(preferences.animationsEnabled && !reduceMotion ? .easeOut(duration: 0.30) : nil) {
            visible = true
        }
    }
}

// UI-UPGRADE: Decorates the original native Slider; never writes its value or intercepts its binding.
struct PremiumSliderFeedback: ViewModifier {
    let value: Double
    let range: ClosedRange<Double>
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.isEnabled) private var isEnabled
    @GestureState private var isDragging = false

    private var fraction: CGFloat {
        CGFloat(min(1, max(0, (value - range.lowerBound) / max(0.001, range.upperBound - range.lowerBound))))
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    let inset: CGFloat = 14
                    let width = max(0, geometry.size.width - inset * 2)
                    let x = inset + width * (layoutDirection == .rightToLeft ? 1 - fraction : fraction)
                    ZStack(alignment: .topLeading) {
                        Capsule()
                            .fill(IrfaaliTheme.accent.opacity(isDragging ? 0.45 : 0.12))
                            .frame(width: max(0, width * fraction), height: 4)
                            .blur(radius: isDragging ? 5 : 2)
                            .offset(x: layoutDirection == .rightToLeft ? x : inset, y: geometry.size.height / 2 - 2)
                        // Visual thumb cap follows the native control; all touch/accessibility stays native.
                        Circle()
                            .fill(.white)
                            .frame(width: 28, height: 28)
                            .shadow(color: IrfaaliTheme.accent.opacity(0.45), radius: 8)
                            .scaleEffect(isDragging && !reduceMotion && preferences.animationsEnabled ? 1.2 : 1)
                            .opacity(isDragging ? 1 : 0)
                            .position(x: x, y: geometry.size.height / 2)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, dragging, _ in
                        dragging = isEnabled
                    }
            )
            .animation(preferences.animationsEnabled && !reduceMotion ? .spring(response: 0.28, dampingFraction: 0.7) : nil, value: isDragging)
            .sensoryFeedback(.impact(weight: .light), trigger: isDragging) { old, new in
                !old && new && isEnabled && preferences.hapticsEnabled
            }
            .sensoryFeedback(.selection, trigger: Int(fraction * 40)) { _, _ in
                isDragging && isEnabled && preferences.hapticsEnabled
            }
    }
}

// UI-UPGRADE: Scanner exists only while processing; no processing timers, progress or model writes.
struct PremiumProcessingScanner: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                    paused: reduceMotion || !preferences.animationsEnabled || scenePhase != .active)) { context in
                let animated = preferences.animationsEnabled && !reduceMotion && scenePhase == .active
                let phase = animated ? (1 - cos(context.date.timeIntervalSinceReferenceDate * .pi / 1.8)) / 2 : 0.5
                let y = 12 + max(0, geometry.size.height - 24) * phase
                ZStack(alignment: .top) {
                    if reduceTransparency {
                        Color.black.opacity(0.55)
                    } else {
                        Rectangle().fill(.ultraThinMaterial).opacity(0.55)
                    }
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, .cyan.opacity(0.18), .clear],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(height: 64)
                        .offset(y: y - 32)
                    Capsule()
                        .fill(Color.cyan)
                        .frame(height: 2)
                        .shadow(color: .cyan.opacity(0.85), radius: 7)
                        .shadow(color: .cyan.opacity(0.4), radius: 16)
                        .padding(.horizontal, 10)
                        .offset(y: y)
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
