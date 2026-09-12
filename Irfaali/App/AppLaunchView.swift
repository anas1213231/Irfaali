import SwiftUI

struct AppLaunchView: View {
    @EnvironmentObject private var preferences: AppPreferences

    @State private var showApp = false
    @State private var logoScale: CGFloat = 0.84
    @State private var logoOpacity = 0.0
    @State private var titleOpacity = 0.0
    @State private var titleOffset: CGFloat = 12
    @State private var subtitleOpacity = 0.0
    @State private var glowOpacity = 0.0
    @State private var ringScale: CGFloat = 0.68
    @State private var ringOpacity = 0.0
    @State private var sparkOpacity = 0.0

    var body: some View {
        ZStack {
            if showApp {
                RootView()
                    .transition(.opacity.combined(with: .scale(scale: 1.012)))
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
                    Color(red: 0.006, green: 0.032, blue: 0.028),
                    Color(red: 0.008, green: 0.09, blue: 0.072),
                    Color(red: 0.004, green: 0.022, blue: 0.019)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    IrfaaliTheme.accent.opacity(0.15),
                    IrfaaliTheme.accent.opacity(0.035),
                    .clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 300
            )
            .ignoresSafeArea()
            .opacity(glowOpacity)

            ZStack {
                Circle()
                    .stroke(IrfaaliTheme.accent.opacity(0.14), lineWidth: 1)
                    .frame(width: 248, height: 248)

                Circle()
                    .stroke(.white.opacity(0.06), lineWidth: 1)
                    .frame(width: 292, height: 292)

                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index.isMultiple(of: 2) ? IrfaaliTheme.accent : .white)
                        .frame(width: index.isMultiple(of: 2) ? 5 : 3, height: index.isMultiple(of: 2) ? 5 : 3)
                        .offset(y: index.isMultiple(of: 2) ? -124 : -146)
                        .rotationEffect(.degrees(Double(index) * 90 + 45))
                }
                .opacity(sparkOpacity)
            }
            .scaleEffect(ringScale)
            .opacity(ringOpacity)

            VStack(spacing: 20) {
                // The artwork itself is never recolored, clipped, blurred or filtered.
                Image("OfficialLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 174, height: 174)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .accessibilityLabel(AppBranding.appName)

                VStack(spacing: 7) {
                    Text(AppBranding.appName)
                        .font(.system(size: 36, weight: .bold))
                        .tracking(-0.8)
                        .foregroundStyle(.white)

                    Text(preferences.text(ar: "ارفعها. واضبطها.", en: "Upload. Refine. Done."))
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(preferences.isArabic ? 0 : 0.7)
                        .foregroundStyle(.white.opacity(0.52))
                        .opacity(subtitleOpacity)
                }
                .opacity(titleOpacity)
                .offset(y: titleOffset)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func runLaunchSequence() async {
        guard !showApp else { return }

        if preferences.animationsEnabled {
            withAnimation(.spring(response: 0.56, dampingFraction: 0.78)) {
                logoScale = 1
                logoOpacity = 1
                glowOpacity = 1
                ringScale = 1
                ringOpacity = 1
            }

            try? await Task.sleep(for: .milliseconds(180))

            withAnimation(.easeOut(duration: 0.36)) {
                titleOpacity = 1
                titleOffset = 0
            }

            try? await Task.sleep(for: .milliseconds(150))

            withAnimation(.easeOut(duration: 0.34)) {
                subtitleOpacity = 1
                sparkOpacity = 0.78
            }

            try? await Task.sleep(for: .milliseconds(680))

            withAnimation(.easeInOut(duration: 0.34)) {
                showApp = true
            }
        } else {
            logoScale = 1
            logoOpacity = 1
            titleOpacity = 1
            titleOffset = 0
            subtitleOpacity = 1
            glowOpacity = 1
            ringScale = 1
            ringOpacity = 1
            sparkOpacity = 0.7
            showApp = true
        }
    }
}
