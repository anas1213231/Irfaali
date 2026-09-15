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
                    .modifier(AppLanguageLayout()) // UI-UPGRADE: keep native bars aligned on tab entry
                    .modifier(PremiumTabEntrance(isSelected: selectedTab == .studio)) // UI-UPGRADE
            }
            .tabItem {
                Label(
                    preferences.text(ar: "التعديل", en: "Edit"),
                    systemImage: "slider.horizontal.3"
                )
            }
            .tag(Tab.studio)

            NavigationStack {
                HistoryView()
                    .modifier(AppLanguageLayout()) // UI-UPGRADE: keep native bars aligned on tab entry
                    .modifier(PremiumTabEntrance(isSelected: selectedTab == .videos)) // UI-UPGRADE
            }
            .tabItem {
                Label(
                    preferences.text(ar: "فيديوهاتي", en: "My Videos"),
                    systemImage: "play.rectangle.on.rectangle"
                )
            }
            .tag(Tab.videos)

            NavigationStack {
                SettingsView()
                    .modifier(AppLanguageLayout()) // UI-UPGRADE: keep native bars aligned on tab entry
                    .modifier(PremiumTabEntrance(isSelected: selectedTab == .settings)) // UI-UPGRADE
            }
            .tabItem {
                Label(
                    preferences.text(ar: "الإعدادات", en: "Settings"),
                    systemImage: "gearshape"
                )
            }
            .tag(Tab.settings)
        }
        .modifier(AppLanguageLayout()) // UI-UPGRADE: react to in-app language changes
        .buttonStyle(PremiumInteractiveButtonStyle()) // UI-UPGRADE: inherited by navigation destinations
        .foregroundStyle(IrfaaliTheme.primaryText) // UI-UPGRADE: adaptive crisp type
        .tint(IrfaaliTheme.accent)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .sensoryFeedback(.selection, trigger: selectedTab) { _, _ in
            preferences.hapticsEnabled
        }
    }
}
