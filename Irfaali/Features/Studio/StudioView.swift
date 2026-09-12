import SwiftUI
import PhotosUI
import SwiftData

struct StudioView: View {
    @StateObject private var model = StudioViewModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            IrfaaliTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    if model.isAnalyzing { analyzingCard }
                    if let info = model.info { analysisCard(info) }
                    if let outcome = model.lastOutcome { successCard(outcome) }
                    if let message = model.errorMessage { errorCard(message) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 36)
            }
        }
        .navigationTitle("ارفعلي")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: photoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                do {
                    if let movie = try await newValue.loadTransferable(type: VideoFileTransferable.self) {
                        await model.importVideo(url: movie.url)
                    }
                } catch {
                    model.errorMessage = error.localizedDescription
                }
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.movie]) { result in
            switch result {
            case .success(let url):
                Task {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                    let local = FileManager.default.temporaryDirectory.appendingPathComponent("irfaali-file-\(UUID().uuidString).\(ext)")
                    do {
                        try FileManager.default.copyItem(at: url, to: local)
                        await model.importVideo(url: local)
                    } catch {
                        model.errorMessage = error.localizedDescription
                    }
                }
            case .failure(let error):
                model.errorMessage = error.localizedDescription
            }
        }
    }

    private var hero: some View {
        PremiumSurface {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("VIDEO ENGINE")
                            .font(.caption2.weight(.bold))
                            .tracking(2.4)
                            .foregroundStyle(IrfaaliTheme.accent)
                        Text("حلّل. جهّز. صدّر.")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("بيانات حقيقية من AVFoundation، بلا FPS وهمي وبلا ادعاءات ضغط غير واقعية.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 42, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(IrfaaliTheme.accent)
                }

                HStack(spacing: 10) {
                    PhotosPicker(selection: $photoItem, matching: .videos) {
                        Label("اختيار من الصور", systemImage: "photo.on.rectangle.angled")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PremiumPrimaryButtonStyle())

                    Button { showFileImporter = true } label: {
                        Image(systemName: "folder")
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(PremiumSecondaryButtonStyle())
                }
            }
        }
        .padding(.top, 8)
    }

    private var analyzingCard: some View {
        PremiumSurface {
            HStack(spacing: 14) {
                ProgressView().tint(IrfaaliTheme.accent)
                VStack(alignment: .leading) {
                    Text("جاري التحليل الحقيقي…").font(.headline)
                    Text("نقرأ tracks، codec، FPS، bitrate، الصوت والحاوية.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private func analysisCard(_ info: VideoAssetInfo) -> some View {
        VStack(spacing: 16) {
            PremiumSurface {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("تحليل المصدر").font(.title3.bold())
                            Text(info.fileName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text(info.dynamicRange)
                            .font(.caption.bold())
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(IrfaaliTheme.accent.opacity(0.12), in: Capsule())
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        MetricTile(icon: "rectangle.portrait", title: "الدقة", value: "\(info.width)×\(info.height)")
                        MetricTile(icon: "speedometer", title: "Source FPS", value: IrfaaliFormatters.fps(info.sourceFPS))
                        MetricTile(icon: "film.stack", title: "Video Codec", value: info.videoCodec)
                        MetricTile(icon: "waveform", title: "Video Bitrate", value: IrfaaliFormatters.bitrate(info.estimatedBitrate))
                        MetricTile(icon: "clock", title: "المدة", value: IrfaaliFormatters.duration(info.duration))
                        MetricTile(icon: "internaldrive", title: "الحجم", value: IrfaaliFormatters.byteCount.string(fromByteCount: info.fileSizeBytes))
                    }

                    Divider().overlay(.white.opacity(0.08))
                    compatibilityRow(info)
                }
            }

            PremiumSurface {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Optimization Preset").font(.headline)
                    ForEach(OptimizationPreset.all) { preset in
                        Button {
                            withAnimation(.snappy) { model.selectedPreset = preset }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: model.selectedPreset == preset ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(model.selectedPreset == preset ? IrfaaliTheme.accent : .secondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(preset.title).font(.subheadline.bold()).foregroundStyle(.primary)
                                    Text(preset.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if model.isProcessing {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: model.progress).tint(IrfaaliTheme.accent)
                            Text("\(Int(model.progress * 100))% · تقدم التصدير الفعلي")
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            Task {
                                if let result = await model.process() {
                                    let record = ProcessedVideoRecord(
                                        sourceFileName: info.fileName,
                                        outputURL: result.url,
                                        presetName: model.selectedPreset.title,
                                        width: info.width,
                                        height: info.height,
                                        fps: result.outputFPS,
                                        codec: result.codecLabel
                                    )
                                    modelContext.insert(record)
                                    try? modelContext.save()
                                }
                            }
                        } label: {
                            Label("ابدأ المعالجة", systemImage: "sparkles.rectangle.stack.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PremiumPrimaryButtonStyle())
                    }
                }
            }
        }
    }

    private func compatibilityRow(_ info: VideoAssetInfo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: info.isTikTokPostingAPIFPSCompatible && info.isTikTokPostingAPIResolutionCompatible ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(info.isTikTokPostingAPIFPSCompatible && info.isTikTokPostingAPIResolutionCompatible ? IrfaaliTheme.accent : .orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("TikTok Content Posting API").font(.subheadline.bold())
                Text("المعيار الرسمي الحالي: 23–60fps وأبعاد 360–4096 بكسل لكل محور.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func successCard(_ outcome: ExportOutcome) -> some View {
        PremiumSurface {
            VStack(alignment: .leading, spacing: 12) {
                Label("اكتمل التصدير", systemImage: "checkmark.seal.fill")
                    .font(.headline).foregroundStyle(IrfaaliTheme.accent)
                Text(outcome.fpsClassification.title).font(.title3.bold())
                Text(outcome.fpsClassification.detail).font(.caption).foregroundStyle(.secondary)
                ShareLink(item: outcome.url) {
                    Label("مشاركة الملف", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PremiumSecondaryButtonStyle())
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        PremiumSurface {
            Label(message, systemImage: "exclamationmark.octagon.fill")
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PremiumPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .background(IrfaaliTheme.accent.opacity(configuration.isPressed ? 0.72 : 0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(Color.black)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct PremiumSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(.white.opacity(configuration.isPressed ? 0.10 : 0.065), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.1)) }
            .foregroundStyle(.primary)
    }
}
