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
        .foregroundStyle(.white)
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
                        .foregroundStyle(.white)
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
                        .foregroundStyle(.white)
                    Text(preferences.text(ar: "حقوق ارفعلي", en: "OWNER IDENTITY"))
                        .font(.caption2.bold())
                        .tracking(preferences.isArabic ? 0.2 : 1.8)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 5) {
                    Text(preferences.text(ar: "المالك والمطور", en: "Created & Owned by"))
                        .foregroundStyle(.white)
                    Link(AppBranding.ownerHandle, destination: AppBranding.telegramURL)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                .font(.headline)

                Link(destination: AppBranding.telegramURL) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(.white.opacity(0.15), lineWidth: 0.5)
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(.white)
                        }
                        .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Telegram")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(AppBranding.ownerHandle)
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)

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
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 5) {
                    Text(preferences.text(ar: "فيديوك يطلع نظيف", en: "Clean Output"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
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
