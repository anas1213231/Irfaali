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
                    settingLabel(icon: "character.bubble.fill", ar: "لغة التطبيق", en: "App language")
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

            Section {
                ForEach([AppPreferences.Appearance.light, .dark]) { appearance in
                    Button {
                        withAnimation(preferences.animationsEnabled ? .easeInOut(duration: 0.22) : nil) {
                            preferences.appearance = appearance
                        }
                    } label: {
                        HStack(spacing: 12) {
                            appearanceSwatch(for: appearance)

                            Text(preferences.appearanceName(appearance))
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)

                            Spacer(minLength: 0)

                            Image(systemName: preferences.appearance == appearance ? "checkmark.circle.fill" : "circle")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(
                                    preferences.appearance == appearance
                                        ? IrfaaliTheme.accent
                                        : Color.secondary.opacity(0.65)
                                )
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PremiumInteractiveButtonStyle()) // UI-UPGRADE
                }
            } header: {
                sectionHeader(ar: "المظهر", en: "Appearance")
            }

            Section {
                Link(destination: AppBranding.telegramURL) {
                    HStack(spacing: 12) {
                        Image(systemName: "paperplane.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(IrfaaliTheme.accent)
                            .frame(width: 30, height: 30)
                            .background(IrfaaliTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(preferences.text(ar: "المطور والمالك", en: "Developer and owner"))
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            Text(AppBranding.ownerHandle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                    settingLabel(icon: "info.circle.fill", ar: "عن ارفعلي", en: "About Irfaali")
                }
            } header: {
                sectionHeader(ar: "حول التطبيق", en: "About")
            }

            Section {
                HStack {
                    Text(preferences.text(ar: "الإصدار", en: "Version"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(versionText)
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.primary)
                }
            } footer: {
                Text(AppBranding.copyright)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .sensoryFeedback(.selection, trigger: preferences.language) { _, _ in preferences.hapticsEnabled } // UI-UPGRADE
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ThemeBackground())
        .buttonStyle(PremiumInteractiveButtonStyle()) // UI-UPGRADE: existing links, menus and buttons
        .navigationTitle(preferences.text(ar: "الإعدادات", en: "Settings"))
        .navigationBarTitleDisplayMode(.large)
        .animation(preferences.animationsEnabled ? .easeInOut(duration: 0.22) : nil, value: preferences.language)
        .animation(preferences.animationsEnabled ? .easeInOut(duration: 0.22) : nil, value: preferences.appearance)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 10)
        .onAppear {
            guard !hasAppeared else { return }
            if preferences.animationsEnabled && !reduceMotion {
                withAnimation(.easeOut(duration: 0.40).delay(0.05)) {
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
            .foregroundStyle(IrfaaliTheme.accent)
    }

    private func settingLabel(icon: String, ar: String, en: String) -> some View {
        Label(preferences.text(ar: ar, en: en), systemImage: icon)
            .font(.body.weight(.medium))
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

        return Circle()
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Circle().stroke(.secondary.opacity(0.28), lineWidth: 1))
            .frame(width: 28, height: 28)
    }

    private var versionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1"
    }
}
