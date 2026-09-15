import AVKit
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \ProcessedVideoRecord.createdAt, order: .reverse) private var records: [ProcessedVideoRecord]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var preferences: AppPreferences
    @State private var playingRecord: ProcessedVideoRecord?

    var body: some View {
        ZStack {
            ThemeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    libraryHeader
                        .padding(.bottom, records.isEmpty ? 44 : 22)

                    if records.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(records) { record in
                                videoRow(record)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 44)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.white)
        .navigationTitle(preferences.text(ar: "فيديوهاتي", en: "My Videos"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $playingRecord) { record in
            VideoPreviewSheet(record: record)
                .environmentObject(preferences)
                .presentationBackground(Color.black)
                .presentationCornerRadius(22)
        }
    }

    private var libraryHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                Text(preferences.text(ar: "شغلك.", en: "Your work."))
                    .font(.system(size: 38, weight: .bold))
                    .tracking(preferences.isArabic ? 0 : -1.1)

                Spacer()

                Text("\(records.count)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(records.isEmpty ? Color.white.opacity(0.28) : IrfaaliVisual.electricCyan)
            }

            Text(
                preferences.text(
                    ar: "كل نتيجة جاهزة ترجع لها بسرعة.",
                    en: "Every finished result, ready when you need it."
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 22) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
                    .frame(width: 74, height: 58)

                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(preferences.text(ar: "أول نتيجة بتعيش هني.", en: "Your first result will live here."))
                    .font(.title3.weight(.bold))

                Text(
                    preferences.text(
                        ar: "عالج فيديو، وبتلقى الملف وبياناته جاهزة لك.",
                        en: "Process a video and its final file and details will appear here."
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 20)
    }

    private func videoRow(_ record: ProcessedVideoRecord) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Button {
                    guard record.outputExists else { return }
                    playingRecord = record
                } label: {
                    ZStack {
                        VideoThumbnailView(url: record.outputURL, isAvailable: record.outputExists)

                        Color.black.opacity(record.outputExists ? 0.10 : 0.38)

                        Circle()
                            .fill(Color.black.opacity(0.66))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                            }

                        Image(systemName: record.outputExists ? "play.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(record.outputExists ? .white : .orange)
                            .offset(x: record.outputExists ? 1 : 0)
                    }
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                    }
                }
                .buttonStyle(VIPPlainButtonStyle())
                .disabled(!record.outputExists)

                VStack(alignment: .leading, spacing: 6) {
                    Text(record.sourceFileName)
                        .font(.headline.weight(.bold))
                        .lineLimit(1)

                    Text(record.createdAt.formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(preferences.locale)))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(record.width)×\(record.height) · \(IrfaaliFormatters.fps(record.fps))")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)

                    Text(record.codec)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Menu {
                    if record.outputExists {
                        ShareLink(item: record.outputURL) {
                            Label(preferences.text(ar: "مشاركة", en: "Share"), systemImage: "square.and.arrow.up")
                        }
                    }

                    Button(role: .destructive) {
                        delete(record)
                    } label: {
                        Label(preferences.text(ar: "حذف", en: "Delete"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 40, height: 44)
                        .contentShape(Rectangle())
                }
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(record.outputExists ? IrfaaliVisual.electricCyan : Color.orange)
                    .frame(width: 6, height: 6)

                Text(
                    record.outputExists
                        ? preferences.text(ar: "جاهز", en: "Ready")
                        : preferences.text(ar: "الملف مو موجود بالجهاز", en: "File missing from device")
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(record.outputExists ? Color.white.opacity(0.60) : Color.orange)

                Spacer()

                if record.outputExists {
                    Text(formattedFileSize(record))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }

            IrfaaliHairline()
        }
        .padding(.vertical, 16)
    }

    private func formattedFileSize(_ record: ProcessedVideoRecord) -> String {
        let bytes: Int64
        if record.fileSizeBytes > 0 {
            bytes = record.fileSizeBytes
        } else {
            let attrs = try? FileManager.default.attributesOfItem(atPath: record.outputPath)
            bytes = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        }
        return IrfaaliFormatters.byteCount.string(fromByteCount: bytes)
    }

    private func delete(_ record: ProcessedVideoRecord) {
        let url = record.outputURL
        VideoThumbnailStore.shared.removeThumbnail(for: url)
        if record.outputExists {
            try? FileManager.default.removeItem(at: url)
        }
        modelContext.delete(record)
        try? modelContext.save()
    }
}

private struct VideoPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferences: AppPreferences
    let record: ProcessedVideoRecord

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VideoCanvas(url: record.outputURL, enhancement: .off)
            }
            .foregroundStyle(.white)
            .navigationTitle(record.sourceFileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(preferences.text(ar: "تم", en: "Done")) { dismiss() }
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
