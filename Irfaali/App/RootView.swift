import SwiftUI

struct RootView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @State private var selectedTab: Tab = .studio

    private enum Tab: Hashable {
        case studio
        case videos
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                StudioView()
            }
            .tabItem {
                Label(
                    preferences.text(ar: "التعديل", en: "Studio"),
                    systemImage: "wand.and.stars"
                )
            }
            .tag(Tab.studio)

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label(
                    preferences.text(ar: "فيديوهاتي", en: "Videos"),
                    systemImage: "rectangle.stack.fill"
                )
            }
            .tag(Tab.videos)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(
                    preferences.text(ar: "الإعدادات", en: "Settings"),
                    systemImage: "gearshape.fill"
                )
            }
            .tag(Tab.settings)
        }
        .tint(IrfaaliTheme.accent)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .animation(
            preferences.animationsEnabled ? .easeInOut(duration: 0.22) : nil,
            value: selectedTab
        )
        .sensoryFeedback(.selection, trigger: selectedTab) { _, _ in
            preferences.hapticsEnabled
        }
    }
}
