import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        ZStack {
            ThemeBackground()

            ScrollView {
                VStack(spacing: 18) {
                    identityHero
                    ownershipCard
                    productCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
        }
        .navigationTitle(preferences.text(ar: "عن ارفعلي", en: "About Irfaali"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var identityHero: some View {
        PremiumSurface {
            VStack(spacing: 18) {
                Image("OfficialLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .padding(16)
                    .accessibilityLabel(AppBranding.appName)

                VStack(spacing: 6) {
                    Text(AppBranding.appName)
                        .font(IrfaaliTheme.titleFont(32))
                    Text(preferences.text(ar: "معالجة فيديو موثوقة", en: "Verified video processing"))
                        .font(.subheadline.weight(.semibold))
                        .tracking(0.3)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var ownershipCard: some View {
        PremiumSurface {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(IrfaaliTheme.accent)
                    Text(preferences.text(ar: "حقوق ارفعلي", en: "OWNER IDENTITY"))
                        .font(.caption2.bold())
                        .tracking(preferences.isArabic ? 0.2 : 1.8)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 5) {
                    Text(preferences.text(ar: "المالك والمطور", en: "Created & Owned by"))
                        .foregroundStyle(.primary)
                    Link(AppBranding.ownerHandle, destination: AppBranding.telegramURL)
                        .fontWeight(.bold)
                        .foregroundStyle(IrfaaliTheme.accent)
                }
                .font(.headline)

                Link(destination: AppBranding.telegramURL) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(IrfaaliTheme.accent.opacity(0.12))
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(IrfaaliTheme.accent)
                        }
                        .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Telegram")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(AppBranding.ownerHandle)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PremiumInteractiveButtonStyle()) // UI-UPGRADE

                Divider().opacity(0.25)

                Text(AppBranding.copyright)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var productCard: some View {
        PremiumSurface {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.title2)
                    .foregroundStyle(IrfaaliTheme.accent)
                VStack(alignment: .leading, spacing: 5) {
                    Text(preferences.text(ar: "فيديوك يطلع نظيف", en: "Clean Output"))
                        .font(.headline.weight(.bold))
                    Text(
                        preferences.text(
                            ar: "تظهر هوية ارفعلي داخل التطبيق فقط. لا نضيف علامة مائية أو مقدمة أو خاتمة على فيديوك.",
                            en: "Irfaali keeps its identity inside the app and does not add a watermark, intro or outro to your video."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
