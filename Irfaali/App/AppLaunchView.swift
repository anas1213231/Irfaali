import SwiftUI

struct AppLaunchView: View {
    @EnvironmentObject private var preferences: AppPreferences

    @State private var showApp = false
    @State private var logoScale: CGFloat = 0.78
    @State private var logoOpacity = 0.0
    @State private var titleOpacity = 0.0
    @State private var titleOffset: CGFloat = 14
    @State private var glowOpacity = 0.0

    var body: some View {
        ZStack {
            if showApp {
                RootView()
                    .transition(.opacity.combined(with: .scale(scale: 1.015)))
            } else {
                splash
                    .transition(.opacity)
            }
        }
        .task {
            await runLaunchSequence()
        }
    }

    private var splash: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.008, green: 0.045, blue: 0.038),
                    Color(red: 0.01, green: 0.105, blue: 0.085),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 54)
                .opacity(glowOpacity)

            VStack(spacing: 22) {
                Image("OfficialLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 172, height: 172)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .accessibilityLabel(AppBranding.appName)

                Text(AppBranding.appName)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .tracking(-0.7)
                    .foregroundStyle(.white)
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)
            }
        }
    }

    private func runLaunchSequence() async {
        guard !showApp else { return }

        if preferences.animationsEnabled {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.76)) {
                logoScale = 1
                logoOpacity = 1
                glowOpacity = 1
            }

            try? await Task.sleep(for: .milliseconds(250))

            withAnimation(.easeOut(duration: 0.42)) {
                titleOpacity = 1
                titleOffset = 0
            }

            try? await Task.sleep(for: .milliseconds(850))

            withAnimation(.easeInOut(duration: 0.38)) {
                showApp = true
            }
        } else {
            logoScale = 1
            logoOpacity = 1
            titleOpacity = 1
            titleOffset = 0
            showApp = true
        }
    }
}
