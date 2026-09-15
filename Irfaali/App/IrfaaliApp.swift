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
                .environment(\.locale, preferences.locale)
                .preferredColorScheme(preferences.preferredColorScheme)
        }
        .modelContainer(for: ProcessedVideoRecord.self)
    }
}
