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
            .opacity(selectedTab == .studio ? 1 : 0)
            .animation(
                preferences.animationsEnabled ? .easeInOut(duration: 0.15) : nil,
                value: selectedTab
            )
            .tabItem {
                Label(
                    preferences.text(ar: "تعديل", en: "Edit"),
                    systemImage: "slider.horizontal.3"
                )
            }
            .tag(Tab.studio)

            NavigationStack {
                HistoryView()
            }
            .opacity(selectedTab == .videos ? 1 : 0)
            .animation(
                preferences.animationsEnabled ? .easeInOut(duration: 0.15) : nil,
                value: selectedTab
            )
            .tabItem {
                Label(
                    preferences.text(ar: "فيديوهاتي", en: "My Videos"),
                    systemImage: "play.rectangle.on.rectangle"
                )
            }
            .tag(Tab.videos)

            NavigationStack {
                SettingsView()
            }
            .opacity(selectedTab == .settings ? 1 : 0)
            .animation(
                preferences.animationsEnabled ? .easeInOut(duration: 0.15) : nil,
                value: selectedTab
            )
            .tabItem {
                Label(
                    preferences.text(ar: "الإعدادات", en: "Settings"),
                    systemImage: "gearshape"
                )
            }
            .tag(Tab.settings)
        }
        .foregroundStyle(.white)
        .tint(IrfaaliVisual.electricCyan)
        .buttonStyle(VIPPlainButtonStyle())
        .toolbarBackground(Color.black.opacity(0.96), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .animation(
            preferences.animationsEnabled ? .easeInOut(duration: 0.15) : nil,
            value: selectedTab
        )
        .sensoryFeedback(.selection, trigger: selectedTab) { _, _ in
            preferences.hapticsEnabled
        }
    }
}
