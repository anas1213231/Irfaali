import SwiftUI

struct SettingsView: View {
    var body: some View {
        ZStack {
            IrfaaliTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    developerCard
                    aboutCard
                    accessCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
        }
        .navigationTitle("الإعدادات")
    }

    private var developerCard: some View {
        PremiumSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text("Developer")
                    .font(.caption2.bold())
                    .tracking(1.5)
                    .foregroundStyle(.secondary)

                Link(destination: AppBranding.telegramURL) {
                    HStack(spacing: 13) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(IrfaaliTheme.accent.opacity(0.13))
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(IrfaaliTheme.accent)
                        }
                        .frame(width: 48, height: 48)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(AppBranding.ownerHandle)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Owner · Telegram")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var aboutCard: some View {
        NavigationLink {
            AboutView()
        } label: {
            PremiumSurface {
                HStack(spacing: 13) {
                    Image(systemName: "info.circle.fill")
                        .font(.title2)
                        .foregroundStyle(IrfaaliTheme.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("حول ارفعلي")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("الملكية، الحقوق، الإصدار وهوية المنتج")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.forward")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var accessCard: some View {
        PremiumSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("الوصول", systemImage: "sparkles")
                        .font(.headline)
                    Spacer()
                    Text("FREE")
                        .font(.caption2.bold())
                        .tracking(1.2)
                        .foregroundStyle(IrfaaliTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(IrfaaliTheme.accent.opacity(0.11), in: Capsule())
                }

                Text("جميع قدرات التطبيق الحالية متاحة بدون اشتراك أو Paywall أو Credits أو حدود تصدير مدفوعة أو إعلانات إجبارية.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider().overlay(.white.opacity(0.08))

                HStack {
                    Text("Version")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(versionText)
                        .font(.caption.monospacedDigit().weight(.semibold))
                }
            }
        }
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }
}
