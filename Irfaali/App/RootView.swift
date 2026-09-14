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
                    .modifier(PremiumTabEntrance(isSelected: selectedTab == .studio)) // UI-UPGRADE
            }
            .tabItem {
                Label(
                    preferences.text(ar: "التعديل", en: "Editor"),
                    systemImage: "wand.and.stars"
                )
            }
            .tag(Tab.studio)

            NavigationStack {
                HistoryView()
                    .modifier(PremiumTabEntrance(isSelected: selectedTab == .videos)) // UI-UPGRADE
            }
            .tabItem {
                Label(
                    preferences.text(ar: "فيديوهاتي", en: "My videos"),
                    systemImage: "rectangle.stack.fill"
                )
            }
            .tag(Tab.videos)

            NavigationStack {
                SettingsView()
                    .modifier(PremiumTabEntrance(isSelected: selectedTab == .settings)) // UI-UPGRADE
            }
            .tabItem {
                Label(
                    preferences.text(ar: "الإعدادات", en: "Settings"),
                    systemImage: "gearshape.fill"
                )
            }
            .tag(Tab.settings)
        }
        .buttonStyle(PremiumInteractiveButtonStyle()) // UI-UPGRADE: inherited by navigation destinations
        .tint(IrfaaliTheme.accent)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .animation(
            preferences.animationsEnabled ? .easeInOut(duration: 0.15) : nil,
            value: selectedTab
        )
        .sensoryFeedback(.selection, trigger: selectedTab) { _, _ in
            preferences.hapticsEnabled
        }
    }
}
