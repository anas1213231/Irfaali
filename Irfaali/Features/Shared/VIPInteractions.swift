import SwiftUI

struct VIPPlainButtonStyle: ButtonStyle {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed && preferences.animationsEnabled && !reduceMotion
                    ? 0.97
                    : 1
            )
            .animation(
                preferences.animationsEnabled && !reduceMotion
                    ? (configuration.isPressed
                        ? .linear(duration: 0.035)
                        : .spring(response: 0.18, dampingFraction: 0.84))
                    : nil,
                value: configuration.isPressed
            )
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { oldValue, newValue in
                preferences.hapticsEnabled && !oldValue && newValue
            }
    }
}
