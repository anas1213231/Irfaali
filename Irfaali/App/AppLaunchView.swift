import SwiftUI

struct AppLaunchView: View {
    @State private var isSplashVisible = !SplashLaunchSession.didPlay

    var body: some View {
        ZStack {
            RootView()

            if isSplashVisible {
                SplashVideoView {
                    SplashLaunchSession.didPlay = true
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isSplashVisible = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}

private enum SplashLaunchSession {
    static var didPlay = false
}
