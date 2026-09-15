import SwiftUI

struct ContainerLabView: View {
    var body: some View {
        ZStack {
            IrfaaliTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    PremiumSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Container Details", systemImage: "shippingbox")
                                .font(.title3.bold())
                            Text("عرض معلومات الحاوية ومسار الفيديو للملفات التي تمت معالجتها.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Divider().overlay(.white.opacity(0.08))
                            classification("Source frame rate", "معدل الإطارات الذي يبلّغه مسار الفيديو الأصلي.")
                            classification("Output frame rate", "معدل الإطارات الذي تم التحقق منه في الملف الناتج.")
                            classification("Track timing", "توقيت مسارات الصوت والفيديو داخل الحاوية.")
                        }
                    }
                    PremiumSurface {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Output integrity").font(.headline)
                            Text("يُقبل الملف بعد قراءة خصائصه والتحقق من الأبعاد والفريمات والصوت.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("المختبر")
    }

    private func classification(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline.bold())
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }
}
