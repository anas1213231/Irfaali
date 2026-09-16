import SwiftUI

struct ContainerLabView: View {
    var body: some View {
        ZStack {
            ThemeBackground()

            ScrollView {
                VStack(spacing: 16) {
                    PremiumSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Container Details", systemImage: "shippingbox")
                                .font(IrfaaliTypography.groupTitle)

                            Text("عرض معلومات الحاوية ومسار الفيديو للملفات التي تمت معالجتها.")
                                .font(IrfaaliTypography.secondaryBody)
                                .foregroundStyle(.secondary)

                            Divider()
                                .overlay(Color.primary.opacity(0.08))

                            classification("Source frame rate", "معدل الإطارات الذي يبلّغه مسار الفيديو الأصلي.")
                            classification("Output frame rate", "معدل الإطارات الذي تم التحقق منه في الملف الناتج.")
                            classification("Track timing", "توقيت مسارات الصوت والفيديو داخل الحاوية.")
                        }
                    }

                    PremiumSurface {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Output integrity")
                                .font(IrfaaliTypography.control)

                            Text("يُقبل الملف بعد قراءة خصائصه والتحقق من الأبعاد والفريمات والصوت.")
                                .font(IrfaaliTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
            }
        }
        .foregroundStyle(.primary)
        .navigationTitle("المختبر")
    }

    private func classification(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(IrfaaliTypography.control)

            Text(detail)
                .font(IrfaaliTypography.caption)
                .foregroundStyle(.secondary)
        }
    }
}
