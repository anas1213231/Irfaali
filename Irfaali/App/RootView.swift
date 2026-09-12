import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { StudioView() }
                .tabItem { Label("الاستوديو", systemImage: "wand.and.stars.inverse") }
            NavigationStack { HistoryView() }
                .tabItem { Label("السجل", systemImage: "clock.arrow.circlepath") }
            NavigationStack { ContainerLabView() }
                .tabItem { Label("المختبر", systemImage: "atom") }
            NavigationStack { SettingsView() }
                .tabItem { Label("الإعدادات", systemImage: "gearshape.fill") }
        }
        .tint(IrfaaliTheme.accent)
    }
}
