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
            .listRowBackground(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.15), lineWidth: 0.5)
                }
            )

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
                                .foregroundStyle(.white)

                            Spacer(minLength: 0)

                            Image(systemName: preferences.appearance == appearance ? "checkmark.circle.fill" : "circle")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(
                                    preferences.appearance == appearance
                                        ? Color.white
                                        : Color.secondary.opacity(0.65)
                                )
                        }
                        .contentShape(Rectangle())
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                sectionHeader(ar: "المظهر", en: "Appearance")
            }
            .listRowBackground(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.15), lineWidth: 0.5)
                }
            )

            Section {
                Link(destination: AppBranding.telegramURL) {
                    HStack(spacing: 12) {
                        Image(systemName: "paperplane.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(preferences.text(ar: "المطور والمالك", en: "Developer and owner"))
                                .font(.body.weight(.medium))
                                .foregroundStyle(.white)
                            Text(AppBranding.ownerHandle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                NavigationLink {
                    AboutView()
                } label: {
                    settingLabel(icon: "info.circle.fill", ar: "عن ارفعلي", en: "About Irfaali")
                }
            } header: {
                sectionHeader(ar: "حول التطبيق", en: "About")
            }
            .listRowBackground(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.15), lineWidth: 0.5)
                }
            )

            Section {
                HStack {
                    Text(preferences.text(ar: "الإصدار", en: "Version"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(versionText)
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                }
            } footer: {
                Text(AppBranding.copyright)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .listRowBackground(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.15), lineWidth: 0.5)
                }
            )
        }
        .foregroundStyle(.white)
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ThemeBackground())
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
            .foregroundStyle(.secondary)
    }

    private func settingLabel(icon: String, ar: String, en: String) -> some View {
        Label(preferences.text(ar: ar, en: en), systemImage: icon)
            .font(.body.weight(.medium))
            .foregroundStyle(.white)
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
            colors = [Color(white: 0.72), .white]
        case .pureWhite:
            colors = [.white, .white]
        }

        return Circle()
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 0.5))
            .frame(width: 28, height: 28)
    }

    private var versionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1"
    }
}
