import SwiftUI
import SwiftData
import AVKit

struct HistoryView: View {
    @Query(sort: \ProcessedVideoRecord.createdAt, order: .reverse) private var records: [ProcessedVideoRecord]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var preferences: AppPreferences
    @State private var playingRecord: ProcessedVideoRecord?

    var body: some View {
        ZStack {
            ThemeBackground()

            if records.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        libraryHeader

                        ForEach(records) { record in
                            videoCard(record)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle(preferences.text(ar: "فيديوهاتي", en: "Videos"))
        .sheet(item: $playingRecord) { record in
            VideoPreviewSheet(record: record)
                .environmentObject(preferences)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                preferences.text(ar: "المكان فاضي للحين 👀", en: "No processed videos yet"),
                systemImage: "play.rectangle.on.rectangle.fill"
            )
        } description: {
            Text(
                preferences.text(
                    ar: "أول فيديو تضبطه بيطلع لك هني بكل بياناته.",
                    en: "Your processed videos will appear here with their real output details."
                )
            )
        }
    }

    private var libraryHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(preferences.text(ar: "شغلك كله بمكان واحد", en: "Your processed library"))
                    .font(.title3.weight(.bold))
                Text(
                    preferences.text(
                        ar: "محفوظ محليًا ويرجع لك حتى بعد ما تسكر التطبيق.",
                        en: "Stored locally and available when you come back."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(records.count)")
                .font(.headline.monospacedDigit().weight(.bold))
                .foregroundStyle(IrfaaliTheme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(IrfaaliTheme.accent.opacity(0.10), in: Capsule())
        }
        .padding(.bottom, 2)
    }

    private func videoCard(_ record: ProcessedVideoRecord) -> some View {
        PremiumSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 13) {
                    Button {
                        guard record.outputExists else { return }
                        playingRecord = record
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [IrfaaliTheme.emerald.opacity(0.9), IrfaaliTheme.ink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 38, height: 38)
                            Image(systemName: record.outputExists ? "play.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(record.outputExists ? IrfaaliTheme.accent : .orange)
                        }
                        .frame(width: 76, height: 76)
                    }
                    .buttonStyle(.plain)
                    .disabled(!record.outputExists)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(record.sourceFileName)
                            .font(.headline.weight(.bold))
                            .lineLimit(1)

                        Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(record.presetName)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(IrfaaliTheme.accent)
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
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    metadataChip(icon: "rectangle.portrait", text: "\(record.width)×\(record.height)")
                    metadataChip(icon: "speedometer", text: IrfaaliFormatters.fps(record.fps))
                    metadataChip(icon: "film", text: record.codec)
                }

                HStack {
                    Label(
                        record.outputExists
                            ? preferences.text(ar: "جاهز عندك", en: "Ready")
                            : preferences.text(ar: "الملف مو موجود بالجهاز", en: "File missing from device"),
                        systemImage: record.outputExists ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(record.outputExists ? IrfaaliTheme.accent : .orange)

                    Spacer()

                    if record.outputExists {
                        Text(formattedFileSize(record))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func metadataChip(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
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
        if record.outputExists {
            try? FileManager.default.removeItem(at: record.outputURL)
        }
        modelContext.delete(record)
        try? modelContext.save()
    }
}

private struct VideoPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferences: AppPreferences
    let record: ProcessedVideoRecord

    @State private var player: AVPlayer

    init(record: ProcessedVideoRecord) {
        self.record = record
        _player = State(initialValue: AVPlayer(url: record.outputURL))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VideoPlayer(player: player)
                    .ignoresSafeArea(edges: .horizontal)
            }
            .navigationTitle(record.sourceFileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(preferences.text(ar: "تم", en: "Done")) {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear { player.play() }
            .onDisappear { player.pause() }
        }
    }
}
