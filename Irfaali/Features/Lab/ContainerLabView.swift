import SwiftUI

struct ContainerLabView: View {
    var body: some View {
        ZStack {
            IrfaaliTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    PremiumSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Experimental Container Lab", systemImage: "atom")
                                .font(.title3.bold())
                            Text("المرحلة الحالية Read‑Only عمدًا: نعرض الفرق بين native/generated/retimed/container timing بدون تعديل atoms أو تقديم FPS وهمي.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Divider().overlay(.white.opacity(0.08))
                            classification("Native Source FPS", "معدل الإطارات في المصدر كما يبلّغ عنه مسار الفيديو.")
                            classification("Generated FPS", "يتطلب إنشاء إطارات فعلية بالـ duplication أو interpolation ويجب تسميته بوضوح.")
                            classification("Container Timing Experiment", "تغيير timing metadata وحده لا يصنع frames جديدة.")
                        }
                    }
                    PremiumSurface {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Safety Gate").font(.headline)
                            Text("لن يكتب المختبر MP4/MOV atoms قبل وجود parser/validator واختبارات round‑trip. هذا يمنع فساد الملفات وادعاءات 120fps غير الحقيقية.")
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
