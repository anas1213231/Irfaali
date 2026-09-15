import SwiftUI

struct AppLaunchView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isReady = false
    @State private var hasStarted = false
    @State private var logoIsVisible = false
    @State private var copyIsVisible = false

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
            Color.black
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    IrfaaliVisual.coolBlue.opacity(0.08),
                    IrfaaliVisual.deepViolet.opacity(0.02),
                    .clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Image("OfficialLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 148, height: 148)
                    .scaleEffect(logoIsVisible ? 1 : 0.985)
                    .opacity(logoIsVisible ? 1 : 0)
                    .accessibilityLabel(AppBranding.appName)

                VStack(spacing: 5) {
                    Text(AppBranding.appName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)

                    Text(preferences.text(ar: "كل لقطة. بشكل أفضل.", en: "Every frame. Refined."))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .opacity(copyIsVisible ? 1 : 0)
                .offset(y: copyIsVisible ? 0 : 5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .combine)
    }

    private func completeLaunch() async {
        let animated = preferences.animationsEnabled && !reduceMotion

        if animated {
            withAnimation(.easeOut(duration: 0.22)) {
                logoIsVisible = true
            }

            do { try await Task.sleep(for: .milliseconds(90)) } catch { return }

            withAnimation(.easeOut(duration: 0.18)) {
                copyIsVisible = true
            }
        } else {
            logoIsVisible = true
            copyIsVisible = true
        }

        do {
            try await Task.sleep(for: animated ? .milliseconds(360) : .milliseconds(180))
        } catch {
            return
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.15)) {
                isReady = true
            }
        } else {
            isReady = true
        }
    }
}
