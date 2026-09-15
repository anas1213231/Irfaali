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
                    Text(preferences.text(ar: "معالجة فيديو موثوقة", en: "Reliable video processing"))
                        .font(.subheadline.weight(.semibold))
                        .tracking(0.3)
                        .foregroundStyle(IrfaaliTheme.silver)
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
                    Image(systemName: "crown")
                        .foregroundStyle(IrfaaliTheme.silver)
                    Text(preferences.text(ar: "حقوق ارفعلي", en: "Ownership"))
                        .font(.caption2.bold())
                        .tracking(preferences.isArabic ? 0.2 : 1.2)
                        .foregroundStyle(IrfaaliTheme.silver)
                }

                HStack(spacing: 5) {
                    Text(preferences.text(ar: "المالك والمطور", en: "Developer and owner"))
                        .foregroundStyle(IrfaaliTheme.primaryText)
                    Link(AppBranding.ownerHandle, destination: AppBranding.telegramURL)
                        .fontWeight(.bold)
                        .foregroundStyle(IrfaaliTheme.accent)
                }
                .font(.headline)

                Link(destination: AppBranding.telegramURL) {
                    HStack(spacing: 12) {
                        ZStack {
                            ObsidianGlass(cornerRadius: 14)
                            Image(systemName: "paperplane")
                                .foregroundStyle(IrfaaliTheme.accent)
                        }
                        .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Telegram")
                                .font(.caption)
                                .foregroundStyle(IrfaaliTheme.silver)
                            Text(AppBranding.ownerHandle)
                                .font(.subheadline.bold())
                                .foregroundStyle(IrfaaliTheme.primaryText)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.bold())
                            .foregroundStyle(IrfaaliTheme.silver)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PremiumInteractiveButtonStyle()) // UI-UPGRADE

                Divider().opacity(0.20)

                Text(AppBranding.copyright)
                    .font(.caption)
                    .foregroundStyle(IrfaaliTheme.silver)
            }
        }
    }

    private var productCard: some View {
        PremiumSurface {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "checkmark.shield")
                    .font(.title2)
                    .foregroundStyle(IrfaaliTheme.silver)
                VStack(alignment: .leading, spacing: 5) {
                    Text(preferences.text(ar: "فيديوك يطلع نظيف", en: "Clean output"))
                        .font(.headline.weight(.bold))
                    Text(
                        preferences.text(
                            ar: "تظهر هوية ارفعلي داخل التطبيق فقط. لا نضيف علامة مائية أو مقدمة أو خاتمة على فيديوك.",
                            en: "Irfaali keeps its identity inside the app and does not add a watermark, intro or outro to your video."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(IrfaaliTheme.silver)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
