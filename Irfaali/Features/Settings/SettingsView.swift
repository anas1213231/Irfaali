import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        ZStack {
            ThemeBackground()

            ScrollView {
                VStack(spacing: 16) {
                    languageCard
                    appearanceCard
                    experienceCard
                    developerCard
                    aboutCard
                    versionFooter
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
        }
        .navigationTitle(preferences.text(ar: "الإعدادات", en: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .animation(preferences.animationsEnabled ? .snappy : nil, value: preferences.language)
        .animation(preferences.animationsEnabled ? .snappy : nil, value: preferences.appearance)
    }

    private var languageCard: some View {
        PremiumSurface {
            VStack(alignment: .leading, spacing: 14) {
                Label(
                    preferences.text(ar: "لغة التطبيق", en: "App Language"),
                    systemImage: "character.bubble.fill"
                )
                .font(.headline.weight(.bold))

                Picker("Language", selection: $preferences.language) {
                    Text("العربية").tag(AppPreferences.Language.arabic)
                    Text("English").tag(AppPreferences.Language.english)
                }
                .pickerStyle(.segmented)

                Text(
                    preferences.text(
                        ar: "اختار اللغة اللي تناسبك.",
                        en: "Choose your language and the interface direction updates automatically."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var appearanceCard: some View {
        PremiumSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(
                        preferences.text(ar: "ثيم التطبيق", en: "Appearance"),
                        systemImage: "circle.lefthalf.filled"
                    )
                    .font(.headline.weight(.bold))

                    Spacer()

                    Text(preferences.appearanceName(preferences.appearance))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(IrfaaliTheme.accent)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 10)], spacing: 10) {
                    ForEach(AppPreferences.Appearance.allCases) { appearance in
                        Button { preferences.appearance = appearance } label: {
                            VStack(spacing: 10) {
                                themePreview(for: appearance)
                                Text(preferences.appearanceName(appearance))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Image(systemName: preferences.appearance == appearance ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(preferences.appearance == appearance ? IrfaaliTheme.accent : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(preferences.appearance == appearance ? IrfaaliTheme.accent : .clear, lineWidth: 1.5)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(preferences.appearance == appearance ? .isSelected : [])
                    }
                }
            }
        }
    }

    private var experienceCard: some View {
        PremiumSurface {
            VStack(spacing: 14) {
                Toggle(isOn: $preferences.animationsEnabled) {
                    Label(
                        preferences.text(ar: "الحركة والتأثيرات", en: "Animations & Motion"),
                        systemImage: "sparkles"
                    )
                    .font(.subheadline.weight(.semibold))
                }
                .tint(IrfaaliTheme.accent)

                Divider().opacity(0.3)

                Toggle(isOn: $preferences.hapticsEnabled) {
                    Label(
                        preferences.text(ar: "اهتزازات اللمس", en: "Haptic Feedback"),
                        systemImage: "iphone.radiowaves.left.and.right"
                    )
                    .font(.subheadline.weight(.semibold))
                }
                .tint(IrfaaliTheme.accent)
            }
        }
    }

    private var developerCard: some View {
        PremiumSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text(preferences.text(ar: "المالك", en: "OWNER"))
                    .font(.caption2.bold())
                    .tracking(preferences.isArabic ? 0.2 : 1.5)
                    .foregroundStyle(.secondary)

                Link(destination: AppBranding.telegramURL) {
                    HStack(spacing: 13) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(IrfaaliTheme.accent.opacity(0.13))
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(IrfaaliTheme.accent)
                        }
                        .frame(width: 48, height: 48)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(AppBranding.ownerHandle)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)
                            Text(preferences.text(ar: "تلجرام · حقوق ارفعلي", en: "Telegram · Irfaali owner"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var aboutCard: some View {
        NavigationLink {
            AboutView()
        } label: {
            PremiumSurface {
                HStack(spacing: 13) {
                    Image(systemName: "info.circle.fill")
                        .font(.title2)
                        .foregroundStyle(IrfaaliTheme.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(preferences.text(ar: "عن ارفعلي", en: "About Irfaali"))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                        Text(
                            preferences.text(
                                ar: "الحقوق، الإصدار وهوية التطبيق",
                                en: "Ownership, version and app identity"
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.forward")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var versionFooter: some View {
        Text(preferences.text(ar: "ارفعلي · الإصدار \(versionText)", en: "Irfaali · Version \(versionText)"))
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.vertical, 12)
    }

    @ViewBuilder
    private func themePreview(for appearance: AppPreferences.Appearance) -> some View {
        let colors: [Color] = {
            switch appearance {
            case .system:
                [.white, .black]
            case .pureBlack:
                [.black, .black]
            case .dark:
                [Color(white: 0.10), Color(white: 0.18)]
            case .light:
                [Color(white: 0.82), .white]
            case .pureWhite:
                [.white, .white]
            }
        }()

        Circle()
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(Circle().stroke(.secondary.opacity(0.25), lineWidth: 1))
            .frame(width: 30, height: 30)
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        return version
    }
}
