import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        List {
            Section {
                Picker(selection: $preferences.language) {
                    Text("العربية").tag(AppPreferences.Language.arabic)
                    Text("English").tag(AppPreferences.Language.english)
                } label: {
                    settingLabel(icon: "character.bubble", ar: "لغة التطبيق", en: "App language")
                }
                .pickerStyle(.menu)
            } header: {
                sectionHeader(ar: "اللغة", en: "Language")
            } footer: {
                Text(
                    preferences.text(
                        ar: "يتغير اتجاه الواجهة تلقائيًا مع اختيار اللغة.",
                        en: "The interface direction follows your language."
                    )
                )
            }
            .listRowBackground(ObsidianGlass(cornerRadius: 0)) // UI-UPGRADE

            Section {
                ForEach([AppPreferences.Appearance.light, .dark]) { appearance in
                    Button {
                        withAnimation(preferences.animationsEnabled ? .easeInOut(duration: 0.15) : nil) {
                            preferences.appearance = appearance
                        }
                    } label: {
                        HStack(spacing: 12) {
                            appearanceSwatch(for: appearance)

                            Text(preferences.appearanceName(appearance))
                                .font(.body.weight(.semibold))
                                .foregroundStyle(IrfaaliTheme.primaryText)

                            Spacer(minLength: 0)

                            if preferences.appearance == appearance {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(IrfaaliTheme.accent)
                            }
                        }
                        .overlay(alignment: .bottom) {
                            if preferences.appearance == appearance {
                                Rectangle()
                                    .fill(IrfaaliTheme.luminousAccent)
                                    .frame(height: 0.75)
                                    .shadow(color: IrfaaliTheme.accent.opacity(0.18), radius: 2)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PremiumInteractiveButtonStyle()) // UI-UPGRADE
                }
            } header: {
                sectionHeader(ar: "المظهر", en: "Appearance")
            }
            .listRowBackground(ObsidianGlass(cornerRadius: 0)) // UI-UPGRADE

            Section {
                Link(destination: AppBranding.telegramURL) {
                    HStack(spacing: 12) {
                        Image(systemName: "paperplane")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(IrfaaliTheme.accent)
                            .frame(width: 30, height: 30)
                            .background(ObsidianGlass(cornerRadius: 9))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(preferences.text(ar: "المطور والمالك", en: "Developer and owner"))
                                .font(.body.weight(.semibold))
                                .foregroundStyle(IrfaaliTheme.primaryText)
                            Text(AppBranding.ownerHandle)
                                .font(.caption)
                                .foregroundStyle(IrfaaliTheme.silver)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                }

                NavigationLink {
                    AboutView()
                } label: {
                    settingLabel(icon: "info.circle", ar: "عن ارفعلي", en: "About Irfaali")
                }
            } header: {
                sectionHeader(ar: "حول التطبيق", en: "About")
            }
            .listRowBackground(ObsidianGlass(cornerRadius: 0)) // UI-UPGRADE

            Section {
                HStack {
                    Text(preferences.text(ar: "الإصدار", en: "Version"))
                        .foregroundStyle(IrfaaliTheme.silver)
                    Spacer()
                    Text(versionText)
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundStyle(IrfaaliTheme.primaryText)
                }
            } footer: {
                Text(AppBranding.copyright)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .listRowBackground(ObsidianGlass(cornerRadius: 0)) // UI-UPGRADE
        }
        .sensoryFeedback(.selection, trigger: preferences.language) { _, _ in preferences.hapticsEnabled } // UI-UPGRADE
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ThemeBackground())
        .buttonStyle(PremiumInteractiveButtonStyle()) // UI-UPGRADE: existing links, menus and buttons
        .navigationTitle(preferences.text(ar: "الإعدادات", en: "Settings"))
        .navigationBarTitleDisplayMode(.large)
        .animation(preferences.animationsEnabled ? .easeInOut(duration: 0.15) : nil, value: preferences.language)
        .animation(preferences.animationsEnabled ? .easeInOut(duration: 0.15) : nil, value: preferences.appearance)
        .opacity(hasAppeared ? 1 : 0)
        .onAppear {
            guard !hasAppeared else { return }
            if preferences.animationsEnabled && !reduceMotion {
                withAnimation(.easeInOut(duration: 0.15)) {
                    hasAppeared = true
                }
            } else {
                hasAppeared = true
            }
        }
    }

    private func sectionHeader(ar: String, en: String) -> some View {
        Text(preferences.text(ar: ar, en: en))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(IrfaaliTheme.silver)
    }

    private func settingLabel(icon: String, ar: String, en: String) -> some View {
        Label(preferences.text(ar: ar, en: en), systemImage: icon)
            .font(.body.weight(.semibold))
    }

    private func appearanceSwatch(for appearance: AppPreferences.Appearance) -> some View {
        let colors: [Color]
        switch appearance {
        case .system:
            colors = [.white, .black]
        case .pureBlack:
            colors = [.black, .black]
        case .dark:
            colors = [IrfaaliTheme.secondaryInk, IrfaaliTheme.ink]
        case .light:
            colors = [Color(red: 0.80, green: 0.89, blue: 1.0), .white]
        case .pureWhite:
            colors = [.white, .white]
        }

        let selected = preferences.appearance == appearance

        return Circle()
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Circle()
                    .strokeBorder(
                        selected ? IrfaaliTheme.accent : Color.secondary.opacity(0.28),
                        lineWidth: selected ? 1.5 : 1
                    )
            }
            .shadow(color: selected ? IrfaaliTheme.accent.opacity(0.16) : .clear, radius: 4)
            .frame(width: 28, height: 28)
    }

    private var versionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1"
    }
}
