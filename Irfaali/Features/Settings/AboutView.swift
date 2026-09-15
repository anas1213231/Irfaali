import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        ZStack {
            ThemeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    identityHero
                    ownershipSection
                    productSection
                    IrfaaliFooterSignature()
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 44)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.white)
        .navigationTitle(preferences.text(ar: "عن ارفعلي", en: "About Irfaali"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var identityHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image("OfficialLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 98, height: 98)
                .accessibilityLabel(AppBranding.appName)

            VStack(alignment: .leading, spacing: 6) {
                Text(AppBranding.appName)
                    .font(.system(size: 38, weight: .bold))

                Text(preferences.text(ar: "فيديوك. بطريقتك.", en: "Your video. Refined your way."))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var ownershipSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionEyebrow(preferences.text(ar: "الهوية", en: "Identity"))

            Link(destination: AppBranding.telegramURL) {
                HStack(spacing: 14) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))
                        .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(preferences.text(ar: "المالك والمطور", en: "Created & owned by"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(AppBranding.ownerHandle)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(IrfaaliVisual.electricCyan)
                }
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(VIPPlainButtonStyle())

            IrfaaliHairline()

            Text(AppBranding.copyright)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var productSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionEyebrow(preferences.text(ar: "الفكرة", en: "The product"))

            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(IrfaaliVisual.electricCyan.opacity(0.08))
                        .frame(width: 42, height: 42)
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(IrfaaliVisual.electricCyan)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(preferences.text(ar: "الفيديو يظل لك", en: "Your video stays yours"))
                        .font(.headline.weight(.bold))

                    Text(
                        preferences.text(
                            ar: "هوية ارفعلي تبقى داخل التطبيق. ما نضيف علامة مائية أو مقدمة أو خاتمة على فيديوك.",
                            en: "Irfaali keeps its identity inside the app. No watermark, intro or outro is added to your video."
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func sectionEyebrow(_ title: String) -> some View {
        Text(title.uppercased(with: preferences.locale))
            .font(.caption2.weight(.bold))
            .tracking(preferences.isArabic ? 0.2 : 1.4)
            .foregroundStyle(.tertiary)
    }
}
