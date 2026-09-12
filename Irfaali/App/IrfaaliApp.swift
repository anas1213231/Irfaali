import SwiftUI
import SwiftData

@main
struct IrfaaliApp: App {
    @StateObject private var preferences = AppPreferences()

    var body: some Scene {
        WindowGroup {
            AppLaunchView()
                .environmentObject(preferences)
                .environment(\.layoutDirection, preferences.layoutDirection)
                .preferredColorScheme(preferences.preferredColorScheme)
        }
        .modelContainer(for: ProcessedVideoRecord.self)
    }
}
