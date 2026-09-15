import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            ThemeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    settingsSection(title: preferences.text(ar: "اللغة", en: "Language")) {
                        Menu {
                            Button("العربية") { preferences.language = .arabic }
                            Button("English") { preferences.language = .english }
                        } label: {
                            settingsRow(
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
                        VStack(spacing: 0) {
                            appearanceButton(.dark)
                            IrfaaliHairline()
                            appearanceButton(.light)
                        }
                    }

                    settingsSection(title: preferences.text(ar: "ارفعلي", en: "Irfaali")) {
                        Link(destination: AppBranding.telegramURL) {
                            settingsRow(
                                title: preferences.text(ar: "المطور والمالك", en: "Developer and owner"),
                                value: AppBranding.ownerHandle,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(VIPPlainButtonStyle())

                        IrfaaliHairline()

                        NavigationLink {
                            AboutView()
                        } label: {
                            settingsRow(
                                title: preferences.text(ar: "عن ارفعلي", en: "About Irfaali"),
                                value: nil,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(VIPPlainButtonStyle())
                    }

                    settingsSection(title: preferences.text(ar: "الإصدار", en: "Version")) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(preferences.text(ar: "نسخة التطبيق", en: "App version"))
                                .font(.body.weight(.medium))
                                .foregroundStyle(.white)

                            Spacer()

                            Text(versionText)
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 48)
                    }

                    Text(AppBranding.copyright)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 48)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 5)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.white)
        .navigationTitle(preferences.text(ar: "الإعدادات", en: "Settings"))
        .navigationBarTitleDisplayMode(.large)
        .animation(preferences.animationsEnabled ? .easeInOut(duration: 0.15) : nil, value: preferences.language)
        .animation(preferences.animationsEnabled ? .easeInOut(duration: 0.15) : nil, value: preferences.appearance)
        .onAppear {
            guard !hasAppeared else { return }
            if preferences.animationsEnabled && !reduceMotion {
                withAnimation(.easeOut(duration: 0.20)) {
                    hasAppeared = true
                }
            } else {
                hasAppeared = true
            }
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased(with: preferences.locale))
                .font(.caption2.weight(.semibold))
                .tracking(preferences.isArabic ? 0.15 : 1.15)
                .foregroundStyle(.tertiary)

            content()
        }
    }

    private func settingsRow(
        title: String,
        value: String?,
        showsChevron: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(.white)

            Spacer(minLength: 12)

            if let value {
                Text(value)
                    .font(.subheadline.weight(.regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if showsChevron {
                Image(systemName: preferences.isArabic ? "chevron.left" : "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.28))
            }
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private func appearanceButton(_ appearance: AppPreferences.Appearance) -> some View {
        let selected = preferences.appearance == appearance

        return Button {
            withAnimation(preferences.animationsEnabled ? .easeInOut(duration: 0.15) : nil) {
                preferences.appearance = appearance
            }
        } label: {
            HStack(spacing: 13) {
                appearanceSwatch(for: appearance)

                Text(preferences.appearanceName(appearance))
                    .font(.body.weight(selected ? .semibold : .medium))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: selected ? "checkmark" : "")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selected ? IrfaaliVisual.electricCyan : Color.clear)
                    .frame(width: 18)
            }
            .frame(minHeight: 54)
            .contentShape(Rectangle())
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
            colors = [Color(white: 0.16), .black]
        case .light:
            colors = [Color(white: 0.70), .white]
        case .pureWhite:
            colors = [.white, .white]
        }

        return Circle()
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 0.5))
            .frame(width: 20, height: 20)
    }

    private var versionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1"
    }
}
