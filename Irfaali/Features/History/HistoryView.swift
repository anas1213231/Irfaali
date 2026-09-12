import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \ProcessedVideoRecord.createdAt, order: .reverse) private var records: [ProcessedVideoRecord]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            IrfaaliTheme.background.ignoresSafeArea()
            if records.isEmpty {
                ContentUnavailableView("لا يوجد سجل بعد", systemImage: "clock.arrow.circlepath", description: Text("أي تصدير ناجح سيظهر هنا تلقائيًا."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(records) { record in
                            PremiumSurface {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(record.sourceFileName).font(.headline).lineLimit(1)
                                            Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Menu {
                                            Button(role: .destructive) {
                                                try? FileManager.default.removeItem(at: record.outputURL)
                                                modelContext.delete(record)
                                                try? modelContext.save()
                                            } label: { Label("حذف", systemImage: "trash") }
                                        } label: { Image(systemName: "ellipsis.circle") }
                                    }
                                    Text("\(record.presetName) · \(record.width)×\(record.height) · \(IrfaaliFormatters.fps(record.fps))")
                                        .font(.caption).foregroundStyle(.secondary)
                                    if FileManager.default.fileExists(atPath: record.outputPath) {
                                        ShareLink(item: record.outputURL) { Label("مشاركة", systemImage: "square.and.arrow.up") }
                                    } else {
                                        Label("الملف غير موجود على الجهاز", systemImage: "exclamationmark.triangle")
                                            .font(.caption).foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("السجل")
    }
}
