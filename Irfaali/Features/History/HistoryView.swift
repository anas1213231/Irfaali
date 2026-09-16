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
                        .padding(.bottom, records.isEmpty ? 34 : 8)

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
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 48)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.primary)
        .navigationTitle(preferences.text(ar: "فيديوهاتي", en: "My Videos"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $playingRecord) { record in
            VideoPreviewSheet(record: record)
                .environmentObject(preferences)
                .presentationBackground(Color.black)
                .presentationCornerRadius(20)
        }
    }

    private var libraryHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(
                records.isEmpty
                    ? preferences.text(ar: "ما عندك نتائج للحين", en: "No results yet")
                    : preferences.text(ar: "آخر النتائج", en: "Recent results")
            )
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)

            Spacer()

            if !records.isEmpty {
                Text("\(records.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 24) {
            ZStack {
                Rectangle()
                    .fill(Color.primary.opacity(0.10))
                    .frame(width: 64, height: 0.5)
                Rectangle()
                    .fill(Color.primary.opacity(0.10))
                    .frame(width: 0.5, height: 42)
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.76))
            }
            .frame(width: 64, height: 42)

            VStack(alignment: .leading, spacing: 7) {
                Text(preferences.text(ar: "أول فيديو معالج يظهر هني.", en: "Your first processed video appears here."))
                    .font(.title3.weight(.semibold))

                Text(
                    preferences.text(
                        ar: "الملف النهائي وبياناته يظلون جاهزين لك.",
                        en: "The final file and its details stay ready for you."
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 30)
    }

    private func videoRow(_ record: ProcessedVideoRecord) -> some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                Button {
                    guard record.outputExists else { return }
                    playingRecord = record
                } label: {
                    ZStack {
                        VideoThumbnailView(url: record.outputURL, isAvailable: record.outputExists)
                        Color.black.opacity(record.outputExists ? 0.08 : 0.42)

                        Image(systemName: record.outputExists ? "play.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(record.outputExists ? Color.white.opacity(0.92) : Color.orange)
                            .padding(9)
                            .background(Color.black.opacity(0.56), in: Circle())
                    }
                    .frame(width: 124, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(VIPPlainButtonStyle())
                .disabled(!record.outputExists)

                VStack(alignment: .leading, spacing: 5) {
                    Text(record.sourceFileName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text("\(record.width)×\(record.height) · \(IrfaaliFormatters.fps(record.fps))")
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 7) {
                        Circle()
                            .fill(record.outputExists ? IrfaaliVisual.electricCyan : Color.orange)
                            .frame(width: 4, height: 4)

                        Text(
                            record.outputExists
                                ? preferences.text(ar: "جاهز", en: "Ready")
                                : preferences.text(ar: "الملف غير موجود", en: "File missing")
                        )
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(record.outputExists ? Color.secondary : Color.orange)
                    }
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
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 44)
                        .contentShape(Rectangle())
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Text(record.createdAt.formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(preferences.locale)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                if record.outputExists {
                    Text("\(record.codec) · \(formattedFileSize(record))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
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
