import SwiftUI

struct AboutView: View {
    var body: some View {
        ZStack {
            IrfaaliTheme.background.ignoresSafeArea()

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
        .navigationTitle("حول ارفعلي")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var identityHero: some View {
        PremiumSurface {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(IrfaaliTheme.emerald.opacity(0.55))
                        .frame(width: 108, height: 108)
                        .blur(radius: 18)
                    Circle()
                        .fill(.white.opacity(0.055))
                        .frame(width: 94, height: 94)
                        .overlay {
                            Circle().stroke(.white.opacity(0.12), lineWidth: 1)
                        }
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 58, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(IrfaaliTheme.accent)
                }

                VStack(spacing: 6) {
                    Text(AppBranding.appName)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Premium Video Engine")
                        .font(.subheadline.weight(.semibold))
                        .tracking(0.4)
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
                    Text("OWNER IDENTITY")
                        .font(.caption2.bold())
                        .tracking(1.8)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 5) {
                    Text("Created & Owned by")
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
                .buttonStyle(.plain)

                Divider().overlay(.white.opacity(0.08))

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
                    Text("Clean Output")
                        .font(.headline)
                    Text("حقوق الملكية تظهر داخل التطبيق فقط. لا يضيف ارفعلي شعارًا أو اسم مطور أو Watermark أو Intro/Outro إلى فيديو المستخدم.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
