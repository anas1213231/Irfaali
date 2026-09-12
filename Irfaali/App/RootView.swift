import SwiftUI

struct RootView: View {
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        TabView {
            NavigationStack {
                StudioView()
            }
            .tabItem {
                Label(
                    preferences.text(ar: "التعديل", en: "Studio"),
                    systemImage: "wand.and.stars.inverse"
                )
            }

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label(
                    preferences.text(ar: "فيديوهاتي", en: "Videos"),
                    systemImage: "play.rectangle.on.rectangle.fill"
                )
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(
                    preferences.text(ar: "الإعدادات", en: "Settings"),
                    systemImage: "gearshape.fill"
                )
            }
        }
        .tint(IrfaaliTheme.accent)
    }
}
