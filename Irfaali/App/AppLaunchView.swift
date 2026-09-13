import SwiftUI

struct AppLaunchView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showApp = false

    var body: some View {
        ZStack {
            RootView()
            if !showApp {
                ThemeBackground()
                VStack(spacing: 20) {
                    // Keep the complete official artwork, including its outer edges.
                    Image("OfficialLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 128, height: 128)
                        .padding(24)
                        .accessibilityLabel(AppBranding.appName)
                    Text(AppBranding.appName)
                        .font(.system(size: 30, weight: .bold))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }
        }
        .task {
            guard !showApp else { return }
            guard preferences.animationsEnabled, !reduceMotion else {
                showApp = true
                return
            }
            do { try await Task.sleep(for: .milliseconds(350)) }
            catch { return }
            withAnimation(.easeOut(duration: 0.22)) { showApp = true }
        }
    }
}
