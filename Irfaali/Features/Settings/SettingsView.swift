import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            ThemeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    settingsHero

                    settingsSection(title: preferences.text(ar: "اللغة", en: "Language")) {
                        Menu {
                            Button("العربية") { preferences.language = .arabic }
                            Button("English") { preferences.language = .english }
                        } label: {
                            settingsRow(
                                icon: "character.bubble",
                                title: preferences.text(ar: "لغة التطبيق", en: "App language"),
                                value: preferences.isArabic ? "العربية" : "English",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(VIPPlainButtonStyle())
                        .sensoryFeedback(.selection, trigger: preferences.language.rawValue) { oldValue, newValue in
                            preferences.hapticsEnabled && oldValue != newValue
                        }
                    }

                    settingsSection(title: preferences.text(ar: "المظهر", en: "Appearance")) {
                        HStack(spacing: 10) {
                            appearanceButton(.dark)
                            appearanceButton(.light)
                        }
                    }

                    settingsSection(title: preferences.text(ar: "حول التطبيق", en: "About")) {
                        Link(destination: AppBranding.telegramURL) {
                            settingsRow(
                                icon: "paperplane",
                                title: preferences.text(ar: "المطور والمالك", en: "Developer and owner"),
                                value: AppBranding.ownerHandle,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(VIPPlainButtonStyle())

                        IrfaaliHairline(leadingInset: 48)

                        NavigationLink {
                            AboutView()
                        } label: {
                            settingsRow(
                                icon: "info.circle",
                                title: preferences.text(ar: "عن ارفعلي", en: "About Irfaali"),
                                value: nil,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(VIPPlainButtonStyle())
                    }

                    settingsSection(title: preferences.text(ar: "الإصدار", en: "Version")) {
                        HStack {
                            Text(preferences.text(ar: "نسخة التطبيق", en: "App version"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(versionText)
                                .font(.subheadline.monospacedDigit().weight(.bold))
                                .foregroundStyle(.white)
                        }
                        .frame(minHeight: 44)
                    }

                    Text(AppBranding.copyright)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 44)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 8)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.white)
        .navigationTitle(preferences.text(ar: "الإعدادات", en: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .animation(preferences.animationsEnabled ? .easeInOut(duration: 0.15) : nil, value: preferences.language)
        .animation(preferences.animationsEnabled ? .easeInOut(duration: 0.15) : nil, value: preferences.appearance)
        .onAppear {
            guard !hasAppeared else { return }
            if preferences.animationsEnabled && !reduceMotion {
                withAnimation(.easeOut(duration: 0.28)) {
                    hasAppeared = true
                }
            } else {
                hasAppeared = true
            }
        }
    }

    private var settingsHero: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(preferences.text(ar: "على مزاجك.", en: "Make it yours."))
                .font(.system(size: 36, weight: .bold))
                .tracking(preferences.isArabic ? 0 : -1.0)

            Text(
                preferences.text(
                    ar: "لغة ومظهر، بدون زحمة.",
                    en: "Language and appearance, without the clutter."
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title.uppercased(with: preferences.locale))
                .font(.caption2.weight(.bold))
                .tracking(preferences.isArabic ? 0.2 : 1.4)
                .foregroundStyle(.tertiary)

            content()
        }
    }

    private func settingsRow(
        icon: String,
        title: String,
        value: String?,
        showsChevron: Bool
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.84))
                .frame(width: 34, height: 34)

            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            if let value {
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if showsChevron {
                Image(systemName: preferences.isArabic ? "chevron.left" : "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }

    private func appearanceButton(_ appearance: AppPreferences.Appearance) -> some View {
        let selected = preferences.appearance == appearance

        return Button {
            withAnimation(preferences.animationsEnabled ? .easeInOut(duration: 0.15) : nil) {
                preferences.appearance = appearance
            }
        } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    appearanceSwatch(for: appearance)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selected ? IrfaaliVisual.electricCyan : .tertiary)
                }

                Text(preferences.appearanceName(appearance))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(selected ? .white : .secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
            .background(
                selected ? IrfaaliVisual.electricCyan.opacity(0.07) : IrfaaliVisual.quieterFill,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        selected ? IrfaaliVisual.electricCyan.opacity(0.34) : IrfaaliVisual.hairline,
                        lineWidth: selected ? 0.8 : 0.5
                    )
            }
        }
        .buttonStyle(VIPPlainButtonStyle())
    }

    private func appearanceSwatch(for appearance: AppPreferences.Appearance) -> some View {
        let colors: [Color]
        switch appearance {
        case .system:
            colors = [.white, .black]
        case .pureBlack:
            colors = [.black, .black]
        case .dark:
            colors = [Color(white: 0.22), .black]
        case .light:
            colors = [Color(white: 0.72), .white]
        case .pureWhite:
            colors = [.white, .white]
        }

        return Circle()
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
            .frame(width: 28, height: 28)
    }

    private var versionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1"
    }
}
