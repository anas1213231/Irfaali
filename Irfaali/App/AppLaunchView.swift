import SwiftUI

@MainActor
private enum LaunchPlaybackSession {
    static var didPresentSplash = false
}

struct AppLaunchView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsSplash: Bool

    init() {
        let shouldPresentSplash = !LaunchPlaybackSession.didPresentSplash
        LaunchPlaybackSession.didPresentSplash = true
        _showsSplash = State(initialValue: shouldPresentSplash)
    }

    var body: some View {
        ZStack {
            RootView()

            if showsSplash {
                SplashVideoView {
                    if preferences.animationsEnabled && !reduceMotion {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showsSplash = false
                        }
                    } else {
                        showsSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}
