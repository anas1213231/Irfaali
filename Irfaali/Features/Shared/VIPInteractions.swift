import SwiftUI

struct VIPPlainButtonStyle: ButtonStyle {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed && preferences.animationsEnabled && !reduceMotion
                    ? 0.98
                    : 1
            )
            .animation(
                preferences.animationsEnabled && !reduceMotion
                    ? .easeInOut(duration: 0.10)
                    : nil,
                value: configuration.isPressed
            )
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { oldValue, newValue in
                preferences.hapticsEnabled && !oldValue && newValue
            }
    }
}
