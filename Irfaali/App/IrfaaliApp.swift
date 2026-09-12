import SwiftUI
import SwiftData

@main
struct IrfaaliApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: ProcessedVideoRecord.self)
    }
}
