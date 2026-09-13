import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        ZStack {
            ThemeBackground()

            ScrollView {
                VStack(spacing: 14) {
                    languageCard
                    appearanceCard
                    experienceCard
                    ownerCard
                    aboutCard
                    versionFooter
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(preferences.text(ar: "الإعدادات", en: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .animation(preferences.animationsEnabled ? .easeInOut(duration: 0.22) : nil, value: preferences.language)
        .animation(preferences.animationsEnabled ? .easeInOut(duration: 0.22) : nil, value: preferences.appearance)
    }

    private var languageCard: some View {
        PremiumSurface {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(icon: "character.bubble.fill", ar: "لغة التطبيق", en: "App Language")

                Picker("Language", selection: $preferences.language) {
                    Text("العربية").tag(AppPreferences.Language.arabic)
                    Text("English").tag(AppPreferences.Language.english)
                }
                .pickerStyle(.segmented)

                Text(
                    preferences.text(
                        ar: "يتغير اتجاه الواجهة تلقائيًا مع اختيار اللغة.",
                        en: "The interface direction updates with your language."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var appearanceCard: some View {
        PremiumSurface {
            VStack(alignment: .leading, spacing: 11) {
                sectionTitle(icon: "circle.lefthalf.filled", ar: "مظهر التطبيق", en: "Appearance")

                ForEach(AppPreferences.Appearance.allCases) { appearance in
                    Button {
                        preferences.appearance = appearance
                    } label: {
                        HStack(spacing: 11) {
                            appearanceSwatch(for: appearance)

                            Text(preferences.appearanceName(appearance))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)

                            Spacer(minLength: 0)

                            if preferences.appearance == appearance {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(IrfaaliTheme.accent)
                            }
                        }
                        .contentShape(Rectangle())
                        .frame(minHeight: 38)
                    }
                    .buttonStyle(.plain)

                    if appearance != .pureWhite {
                        Divider().opacity(0.22)
                    }
                }
            }
        }
    }

    private var experienceCard: some View {
        PremiumSurface {
            VStack(spacing: 0) {
                Toggle(isOn: $preferences.animationsEnabled) {
                    Label(
                        preferences.text(ar: "الحركة", en: "Motion"),
                        systemImage: "sparkles"
                    )
                    .font(.subheadline.weight(.semibold))
                }
                .tint(IrfaaliTheme.accent)
                .padding(.vertical, 4)

                Divider().opacity(0.25)

                Toggle(isOn: $preferences.hapticsEnabled) {
                    Label(
                        preferences.text(ar: "اهتزازات اللمس", en: "Haptic Feedback"),
                        systemImage: "iphone.radiowaves.left.and.right"
                    )
                    .font(.subheadline.weight(.semibold))
                }
                .tint(IrfaaliTheme.accent)
                .padding(.vertical, 4)
            }
        }
    }

    private var ownerCard: some View {
        PremiumSurface {
            Link(destination: AppBranding.telegramURL) {
                HStack(spacing: 12) {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                        .foregroundStyle(IrfaaliTheme.accent)
                        .frame(width: 42, height: 42)
                        .background(IrfaaliTheme.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(preferences.text(ar: "المطور والمالك", en: "Developer and owner"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(AppBranding.ownerHandle)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                        Text(preferences.text(ar: "تواصل عبر تيليجرام", en: "Contact on Telegram"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "arrow.up.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var aboutCard: some View {
        NavigationLink {
            AboutView()
        } label: {
            PremiumSurface {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.title3)
                        .foregroundStyle(IrfaaliTheme.accent)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(preferences.text(ar: "عن ارفعلي", en: "About Irfaali"))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                        Text(
                            preferences.text(
                                ar: "الحقوق، الإصدار، وهوية التطبيق",
                                en: "Ownership, version and app identity"
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: preferences.isArabic ? "chevron.left" : "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var versionFooter: some View {
        Text(
            preferences.text(
                ar: "ارفعلي · الإصدار (versionText)",
                en: "Irfaali · Version (versionText)"
            )
        )
        .font(.footnote.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.vertical, 10)
    }

    private func sectionTitle(icon: String, ar: String, en: String) -> some View {
        Label(preferences.text(ar: ar, en: en), systemImage: icon)
            .font(.headline.weight(.bold))
    }

    private func appearanceSwatch(for appearance: AppPreferences.Appearance) -> some View {
        let colors: [Color]
        switch appearance {
        case .system:
            colors = [.white, .black]
        case .pureBlack:
            colors = [.black, .black]
        case .dark:
            colors = [Color(white: 0.12), Color(white: 0.23)]
        case .light:
            colors = [Color(white: 0.82), .white]
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
