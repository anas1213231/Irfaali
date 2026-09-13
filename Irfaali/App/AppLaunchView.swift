import SwiftUI

/// A short, deterministic hand-off from the iOS launch screen to the app.
///
/// The launch artwork is deliberately complete: it is never clipped or
/// recoloured. A single soft settle reveals the logo, followed by the wordmark,
/// with a minimum presentation time so it remains visible when Reduce Motion is
/// enabled.
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
            IrfaaliTheme.launchBackground
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("OfficialLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 156, height: 156)
                    .scaleEffect(logoIsVisible ? 1 : 0.82)
                    .opacity(logoIsVisible ? 1 : 0)
                    .accessibilityLabel(AppBranding.appName)

                VStack(spacing: 6) {
                    Text(AppBranding.appName)
                        .font(.system(size: 34, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                        .opacity(wordmarkIsVisible ? 1 : 0)
                        .offset(y: wordmarkIsVisible ? 0 : 8)

                    Text(preferences.text(ar: "ارفعها. واضبطها.", en: "Upload. Refine. Done."))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .opacity(wordmarkIsVisible ? 1 : 0)
                        .offset(y: wordmarkIsVisible ? 0 : 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .combine)
    }

    private func completeLaunch() async {
        // Keep the logo on screen long enough to be seen. The movement is a
        // single soft settle rather than a bounce or a rotation, so it feels
        // native to iOS while still making the launch state unmistakable.
        let minimumDuration: Duration = preferences.animationsEnabled && !reduceMotion
            ? .milliseconds(1_150)
            : .milliseconds(780)

        if preferences.animationsEnabled && !reduceMotion {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.86)) {
                logoIsVisible = true
            }

            do { try await Task.sleep(for: .milliseconds(180)) } catch { return }

            withAnimation(.easeOut(duration: 0.28)) {
                wordmarkIsVisible = true
            }
        } else {
            logoIsVisible = true
            wordmarkIsVisible = true
        }

        do {
            try await Task.sleep(for: minimumDuration)
        } catch {
            return
        }

        if preferences.animationsEnabled && !reduceMotion {
            withAnimation(.easeInOut(duration: 0.30)) {
                isReady = true
            }
        } else {
            isReady = true
        }
    }
}
