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
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 48)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.primary)
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
                    .font(IrfaaliTypography.brandDisplay)

                Text(preferences.text(ar: "كل لقطة. بشكل أفضل.", en: "Every frame. Refined."))
                    .font(IrfaaliTypography.groupTitle)
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
                    ar: "ارفعلي منصة متقدمة لتحسين وترميم الفيديو، صُممت لتحليل اللقطات ومعالجة جودتها وحركتها وتفاصيلها ضمن تجربة دقيقة وسلسة على iPhone.",
                    en: "Irfaali is an advanced video enhancement and restoration platform built to analyze footage and refine its quality, motion, and detail through a precise, streamlined iPhone experience."
                )
            )
            .font(IrfaaliTypography.body)
            .foregroundStyle(.primary.opacity(0.84))
            .fixedSize(horizontal: false, vertical: true)

            Text(
                preferences.text(
                    ar: "من استعادة التفاصيل وتقليل التشويش إلى رفع الدقة ومعالجة معدل الإطارات، يجمع ارفعلي أدوات الفيديو في مسار واحد يحافظ على طبيعة اللقطة ويمنحك تحكمًا واضحًا في النتيجة.",
                    en: "From detail recovery and noise reduction to resolution enhancement and frame-rate processing, Irfaali brings video tools into one workflow that preserves the character of the footage and keeps the result under your control."
                )
            )
            .font(IrfaaliTypography.secondaryBody)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var ownershipSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionEyebrow(preferences.text(ar: "الهوية", en: "Identity"))

            Link(destination: AppBranding.telegramURL) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preferences.text(ar: "المطور والمالك", en: "Developer & owner"))
                            .font(IrfaaliTypography.caption)
                            .foregroundStyle(.secondary)

                        Text(AppBranding.ownerHandle)
                            .font(IrfaaliTypography.groupTitle)
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(IrfaaliTypography.captionStrong)
                        .foregroundStyle(IrfaaliVisual.electricCyan)
                }
                .frame(minHeight: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(VIPPlainButtonStyle())

            IrfaaliHairline()

            Text(AppBranding.copyright)
                .font(IrfaaliTypography.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var versionLine: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(preferences.text(ar: "الإصدار", en: "Version"))
                .font(IrfaaliTypography.captionStrong)
                .foregroundStyle(.secondary)

            Spacer()

            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1")
                .font(IrfaaliTypography.metadataMonospaced)
                .foregroundStyle(.secondary)
        }
    }

    private func sectionEyebrow(_ title: String) -> some View {
        Text(title.uppercased(with: preferences.locale))
            .font(IrfaaliTypography.captionStrong)
            .tracking(preferences.isArabic ? 0.15 : 1.15)
            .foregroundStyle(.tertiary)
    }
}
