import SwiftUI

// UI-UPGRADE: Presentation-only feedback; existing button actions remain untouched.
struct PremiumPressFeedback: ViewModifier {
    let isPressed: Bool
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && isEnabled && preferences.animationsEnabled && !reduceMotion ? 0.98 : 1)
            .animation(
                preferences.animationsEnabled && !reduceMotion
                    ? .easeInOut(duration: 0.10)
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
            .onAppear { reveal() }
            .onChange(of: isSelected) { _, selected in
                if selected { reveal() } else {
                    withAnimation(preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.15) : nil) {
                        visible = false
                    }
                }
            }
    }

    private func reveal() {
        guard isSelected else { return }
        withAnimation(preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.15) : nil) {
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
                    // UI-UPGRADE: A one-point accent, without blur, a replacement thumb or a pulse.
                    Capsule()
                        .fill(IrfaaliTheme.accent.opacity(isDragging && isEnabled ? 0.65 : 0.25))
                        .frame(width: max(0, width * fraction), height: 1)
                        .offset(x: layoutDirection == .rightToLeft ? x : inset, y: geometry.size.height / 2 - 0.5)
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
            .animation(preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.10) : nil, value: isDragging)
            .sensoryFeedback(.impact(weight: .light), trigger: isDragging) { old, new in
                !old && new && isEnabled && preferences.hapticsEnabled
            }
            .sensoryFeedback(.selection, trigger: Int(fraction * 40)) { _, _ in
                isDragging && isEnabled && preferences.hapticsEnabled
            }
    }
}

