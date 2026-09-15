import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        ZStack {
            ThemeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    identityHero
                    productStatement
                    ownershipSection
                    versionLine
                    IrfaaliFooterSignature()
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 48)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.white)
        .navigationTitle(preferences.text(ar: "عن ارفعلي", en: "About Irfaali"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var identityHero: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image("OfficialLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 92)
                .accessibilityLabel(AppBranding.appName)

            VStack(alignment: .leading, spacing: 7) {
                Text(AppBranding.appName)
                    .font(.system(size: 34, weight: .bold))

                Text(preferences.text(ar: "كل لقطة. بشكل أفضل.", en: "Every frame. Refined."))
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var productStatement: some View {
        VStack(alignment: .leading, spacing: 14) {
            IrfaaliHairline()

            Text(
                preferences.text(
                    ar: "ارفعلي أداة فيديو مصممة حول النتيجة نفسها: صورة أوضح، حركة أدق، وتجربة هادئة.",
                    en: "Irfaali is built around the result itself: clearer imagery, more precise motion, and a calmer workflow."
                )
            )
            .font(.body)
            .foregroundStyle(.white.opacity(0.84))
            .fixedSize(horizontal: false, vertical: true)

            Text(
                preferences.text(
                    ar: "ما نضيف علامة مائية أو مقدمة أو خاتمة على فيديوك.",
                    en: "No watermark, intro or outro is added to your video."
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var ownershipSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionEyebrow(preferences.text(ar: "الهوية", en: "Identity"))

            Link(destination: AppBranding.telegramURL) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preferences.text(ar: "المالك والمطور", en: "Created & owned by"))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(AppBranding.ownerHandle)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(IrfaaliVisual.electricCyan)
                }
                .frame(minHeight: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(VIPPlainButtonStyle())

            IrfaaliHairline()

            Text(AppBranding.copyright)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var versionLine: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(preferences.text(ar: "الإصدار", en: "Version"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func sectionEyebrow(_ title: String) -> some View {
        Text(title.uppercased(with: preferences.locale))
            .font(.caption2.weight(.semibold))
            .tracking(preferences.isArabic ? 0.15 : 1.15)
            .foregroundStyle(.tertiary)
    }
}
