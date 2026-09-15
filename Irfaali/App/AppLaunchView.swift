import SwiftUI

/// UI-UPGRADE: Brief opacity-only launch using the unchanged official artwork.
struct AppLaunchView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isReady = false
    @State private var hasStarted = false
    @State private var logoIsVisible = false
    @State private var wordmarkIsVisible = false

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
            Color("LaunchBackground")
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("OfficialLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .opacity(logoIsVisible ? 1 : 0)
                    .accessibilityLabel(AppBranding.appName)

                VStack(spacing: 6) {
                    Text(preferences.text(ar: "ارفعلي", en: "Irfaali"))
                        .font(.system(size: 28, weight: .semibold, design: .default))
                        .foregroundStyle(IrfaaliTheme.primaryText)
                        .opacity(wordmarkIsVisible ? 1 : 0)

                    Text(preferences.text(ar: "ارفعها. واضبطها.", en: "Upload. Refine. Done."))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(IrfaaliTheme.silver)
                        .opacity(wordmarkIsVisible ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .combine)
    }

    private func completeLaunch() async {
        // UI-UPGRADE: No stagger, scaling or forced splash-screen hold.
        logoIsVisible = true
        wordmarkIsVisible = true
        if preferences.animationsEnabled && !reduceMotion {
            withAnimation(.easeInOut(duration: 0.15)) {
                isReady = true
            }
        } else {
            isReady = true
        }
    }
}
