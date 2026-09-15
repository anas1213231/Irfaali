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
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Image("OfficialLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 32)
                                .accessibilityLabel(AppBranding.appName)
                        }
                    }
            }
            .opacity(selectedTab == .studio ? 1 : 0)
            .animation(
                preferences.animationsEnabled ? .easeInOut(duration: 0.15) : nil,
                value: selectedTab
            )
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
            .opacity(selectedTab == .videos ? 1 : 0)
            .animation(
                preferences.animationsEnabled ? .easeInOut(duration: 0.15) : nil,
                value: selectedTab
            )
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
            .opacity(selectedTab == .settings ? 1 : 0)
            .animation(
                preferences.animationsEnabled ? .easeInOut(duration: 0.15) : nil,
                value: selectedTab
            )
            .tabItem {
                Label(
                    preferences.text(ar: "الإعدادات", en: "Settings"),
                    systemImage: "gearshape.fill"
                )
            }
            .tag(Tab.settings)
        }
        .foregroundStyle(.white)
        .tint(IrfaaliTheme.accent)
        .buttonStyle(VIPPlainButtonStyle())
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
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
