import SwiftUI

/// A short, deterministic hand-off from the iOS launch screen to the app.
///
/// The launch artwork is deliberately static and complete: it is never clipped,
/// recoloured, or scaled with a spring that can make it disappear on a fast
/// device. A minimum presentation time also gives the logo a chance to render
/// when Reduce Motion is enabled.
struct AppLaunchView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isReady = false
    @State private var hasStarted = false

    var body: some View {
        ZStack {
            if isReady {
                RootView()
                    .transition(.opacity)
            } else {
                launchScreen
                    .transition(.opacity)
            }
        }
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            await completeLaunch()
        }
    }

    private var launchScreen: some View {
        ZStack {
            IrfaaliTheme.launchBackground
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Image("OfficialLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 156, height: 156)
                    .accessibilityLabel(AppBranding.appName)

                VStack(spacing: 7) {
                    Text(AppBranding.appName)
                        .font(.system(size: 34, weight: .bold, design: .default))
                        .foregroundStyle(.white)

                    Text(preferences.text(ar: "ارفعها. واضبطها.", en: "Upload. Refine. Done."))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .combine)
    }

    private func completeLaunch() async {
        // Keep the logo on screen long enough to be seen. Reduce Motion changes
        // the transition only; it does not remove the branded launch state.
        let minimumDuration: Duration = preferences.animationsEnabled && !reduceMotion
            ? .milliseconds(950)
            : .milliseconds(700)

        do {
            try await Task.sleep(for: minimumDuration)
        } catch {
            return
        }

        if preferences.animationsEnabled && !reduceMotion {
            withAnimation(.easeOut(duration: 0.24)) {
                isReady = true
            }
        } else {
            isReady = true
        }
    }
}
