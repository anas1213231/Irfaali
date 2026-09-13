import PhotosUI
import SwiftData
import SwiftUI

@MainActor
struct StudioView: View {
    @StateObject private var model = StudioViewModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var showSourceDetails = false
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        ZStack {
            ThemeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    studioIntro
                    importCard

                    if model.isAnalyzing {
                        analyzingCard
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if let info = model.info {
                        sourceCard(info)
                        processingCard(info)
                    }

                    if let outcome = model.lastOutcome {
                        successCard(outcome)
                            .transition(.scale(scale: 0.98).combined(with: .opacity))
                    }

                    if let message = model.validationMessage {
                        statusCard(message, icon: "exclamationmark.triangle.fill", color: .orange)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if let message = model.errorMessage {
                        statusCard(message, icon: "exclamationmark.octagon.fill", color: .red)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, 36)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 10)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(preferences.text(ar: "استوديو الفيديو", en: "Video Studio"))
        .navigationBarTitleDisplayMode(.large)
        .animation(preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.22) : nil, value: model.info?.url)
        .animation(preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.22) : nil, value: model.isAnalyzing)
        .animation(preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.22) : nil, value: model.isProcessing)
        .animation(preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.22) : nil, value: model.lastOutcome?.url)
        .sensoryFeedback(.success, trigger: model.lastOutcome?.url) { _, _ in
            preferences.hapticsEnabled
        }
        .sensoryFeedback(.success, trigger: model.saveState == .saved) { _, _ in
            preferences.hapticsEnabled
        }
        .onAppear {
            guard !hasAppeared else { return }
            if preferences.animationsEnabled && !reduceMotion {
                withAnimation(.easeOut(duration: 0.42).delay(0.05)) {
                    hasAppeared = true
                }
            } else {
                hasAppeared = true
            }
        }
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
                    defer {
                        if access { url.stopAccessingSecurityScopedResource() }
                    }

                    let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                    let local = FileManager.default.temporaryDirectory
                        .appendingPathComponent("irfaali-file-\(UUID().uuidString).\(ext)")

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

    private var studioIntro: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "sparkles.tv.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(IrfaaliTheme.accent)
                .frame(width: 34, height: 34)
                .background(IrfaaliTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            Text(
                preferences.text(
                    ar: "ارفع فيديوك، خلّ ارفعلي يقرأه، وبعدها اختَر الناتج اللي يناسبك.",
                    en: "Add a video, let Irfaali inspect it, then choose the output that fits."
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 3)
    }

    private var importCard: some View {
        let hasVideo = model.info != nil
        let title = preferences.text(
            ar: hasVideo ? "تغيير الفيديو" : "أضف الفيديو",
            en: hasVideo ? "Change Video" : "Add Video"
        )

        return PremiumSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(IrfaaliTheme.accent.opacity(0.14))
                        Image(systemName: hasVideo ? "film.fill" : "video.badge.plus")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(IrfaaliTheme.accent)
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(preferences.text(ar: "مصدر الفيديو", en: "Video source"))
                            .font(.headline.weight(.bold))
                        Text(
                            preferences.text(
                                ar: hasVideo ? "بدّل المقطع إذا تبي." : "اختَر مقطع من الصور أو الملفات.",
                                en: hasVideo ? "Swap the clip whenever you need." : "Choose a clip from Photos or Files."
                            )
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }

                PhotosPicker(selection: $photoItem, matching: .videos) {
                    Label(title, systemImage: hasVideo ? "arrow.triangle.2.circlepath" : "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PremiumPrimaryButtonStyle())
                .disabled(model.isProcessing || model.isAnalyzing)

                Button {
                    showFileImporter = true
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "folder")
                        Text(preferences.text(ar: "اختيار من الملفات", en: "Choose from Files"))
                        Spacer()
                        Image(systemName: preferences.isArabic ? "chevron.left" : "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PremiumSecondaryButtonStyle())
                .disabled(model.isProcessing || model.isAnalyzing)
            }
        }
    }

    private var analyzingCard: some View {
        PremiumSurface {
            HStack(spacing: 13) {
                ProgressView()
                    .controlSize(.regular)
                    .tint(IrfaaliTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(IrfaaliTheme.accent.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(preferences.text(ar: "جاري قراءة الفيديو", en: "Reading the video"))
                        .font(.headline.weight(.bold))
                    Text(
                        preferences.text(
                            ar: "نستخرج الدقة والفريمات والترميز والصوت.",
                            en: "Checking resolution, frame rate, codec and audio."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func sourceCard(_ info: VideoAssetInfo) -> some View {
        PremiumSurface {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .firstTextBaseline) {
                    Label(
                        preferences.text(ar: "بيانات المصدر", en: "Source Details"),
                        systemImage: "doc.text.image"
                    )
                    .font(.headline.weight(.bold))

                    Spacer()

                    Text(info.dynamicRange)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(IrfaaliTheme.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(IrfaaliTheme.accent.opacity(0.11), in: Capsule())
                }

                Text(info.fileName)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    SourceMetric(
                        icon: "rectangle.portrait",
                        title: preferences.text(ar: "الدقة", en: "Resolution"),
                        value: "\(info.width)×\(info.height)"
                    )
                    SourceMetric(
                        icon: "speedometer",
                        title: preferences.text(ar: "الفريمات", en: "Frame Rate"),
                        value: IrfaaliFormatters.fps(info.sourceFPS)
                    )
                }

                DisclosureGroup(
                    preferences.text(ar: "عرض التفاصيل", en: "Show details"),
                    isExpanded: $showSourceDetails
                ) {
                    VStack(spacing: 11) {
                        detailRow(
                            icon: "film.stack",
                            title: preferences.text(ar: "الترميز", en: "Video Codec"),
                            value: info.videoCodec
                        )
                        detailRow(
                            icon: "waveform",
                            title: preferences.text(ar: "البت ريت", en: "Bitrate"),
                            value: IrfaaliFormatters.bitrate(info.estimatedBitrate)
                        )
                        detailRow(
                            icon: "clock",
                            title: preferences.text(ar: "المدة", en: "Duration"),
                            value: IrfaaliFormatters.duration(info.duration)
                        )
                        detailRow(
                            icon: "speaker.wave.2",
                            title: preferences.text(ar: "الصوت", en: "Audio"),
                            value: audioSummary(info)
                        )
                        detailRow(
                            icon: "shippingbox",
                            title: preferences.text(ar: "الحاوية", en: "Container"),
                            value: info.container
                        )
                    }
                    .padding(.top, 11)
                }
                .font(.subheadline.weight(.semibold))
            }
        }
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(IrfaaliTheme.accent)
                .frame(width: 22)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func processingCard(_ info: VideoAssetInfo) -> some View {
        PremiumSurface {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(IrfaaliTheme.accent)
                        .frame(width: 38, height: 38)
                        .background(IrfaaliTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(preferences.text(ar: "إعدادات الإخراج", en: "Output settings"))
                            .font(.headline.weight(.bold))
                        Text(
                            preferences.text(
                                ar: "خيارات تناسب الفيديو اللي اخترته.",
                                en: "Options that fit the video you chose."
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Button {
                        withAnimation(preferences.animationsEnabled ? .snappy : nil) {
                            model.applyRecommendedSettings()
                        }
                    } label: {
                        Text(preferences.text(ar: "موصى به", en: "Recommended"))
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .frame(minHeight: 32)
                    }
                    .buttonStyle(PremiumSecondaryButtonStyle())
                    .disabled(model.isProcessing)
                }

                settingsDivider

                settingsMenuRow(
                    icon: "rectangle.expand.vertical",
                    title: preferences.text(ar: "الدقة", en: "Resolution"),
                    value: model.settings.resolution.title(isArabic: preferences.isArabic)
                ) {
                    ForEach(VideoProcessingSettings.supportedResolutions(for: info)) { resolution in
                        Button {
                            model.settings.resolution = resolution
                        } label: {
                            Label(
                                resolution.title(isArabic: preferences.isArabic),
                                systemImage: model.settings.resolution == resolution ? "checkmark" : "rectangle.portrait"
                            )
                        }
                    }
                }

                settingsDivider

                settingsMenuRow(
                    icon: "speedometer",
                    title: preferences.text(ar: "الفريمات", en: "Frame rate"),
                    value: model.settings.frameRate.title(isArabic: preferences.isArabic)
                ) {
                    ForEach(VideoProcessingSettings.supportedFrameRates(for: info)) { frameRate in
                        Button {
                            model.settings.frameRate = frameRate
                        } label: {
                            Label(
                                frameRate.title(isArabic: preferences.isArabic),
                                systemImage: model.settings.frameRate == frameRate ? "checkmark" : "speedometer"
                            )
                        }
                    }
                }

                settingsDivider

                settingsMenuRow(
                    icon: "cpu",
                    title: preferences.text(ar: "الترميز", en: "Codec"),
                    value: model.settings.codec.title(isArabic: preferences.isArabic)
                ) {
                    ForEach(VideoProcessingSettings.Codec.allCases) { codec in
                        Button {
                            model.settings.codec = codec
                        } label: {
                            Label(
                                codec.title(isArabic: preferences.isArabic),
                                systemImage: model.settings.codec == codec ? "checkmark" : "cpu"
                            )
                        }
                    }
                }

                settingsDivider

                settingsMenuRow(
                    icon: "wand.and.rays",
                    title: preferences.text(ar: "تحسين الصورة", en: "Image enhancement"),
                    value: model.enhancement.mode.title(isArabic: preferences.isArabic)
                ) {
                    ForEach(VideoEnhancementSettings.Mode.allCases) { mode in
                        Button {
                            model.applyEnhancementMode(mode)
                        } label: {
                            Label(
                                mode.title(isArabic: preferences.isArabic),
                                systemImage: model.enhancement.mode == mode ? "checkmark" : "wand.and.rays"
                            )
                        }
                    }
                }

                if model.enhancement.isEnabled {
                    enhancementControls
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                outputSummary(info)
                    .padding(.top, 16)

                if model.isProcessing {
                    processingProgress
                        .padding(.top, 12)
                } else {
                    Button {
                        Task {
                            if let result = await model.process() {
                                let finalInfo = model.outputInfo ?? info
                                let record = ProcessedVideoRecord(
                                    sourceFileName: info.fileName,
                                    outputURL: result.url,
                                    presetName: processingSummary(info),
                                    width: finalInfo.width,
                                    height: finalInfo.height,
                                    fps: finalInfo.sourceFPS,
                                    codec: finalInfo.videoCodec
                                )
                                modelContext.insert(record)
                                try? modelContext.save()
                            }
                        }
                    } label: {
                        HStack(spacing: 9) {
                            Text(preferences.text(ar: "ابدأ المعالجة", en: "Start processing"))
                            Spacer()
                            Image(systemName: preferences.isArabic ? "arrow.left" : "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PremiumPrimaryButtonStyle())
                    .disabled(!model.canProcess)
                    .opacity(model.canProcess ? 1 : 0.48)
                    .padding(.top, 16)
                }
            }
        }
    }

    private var settingsDivider: some View {
        Divider()
            .opacity(0.25)
            .padding(.leading, 36)
    }

    private func settingsMenuRow<MenuContent: View>(
        icon: String,
        title: String,
        value: String,
        @ViewBuilder menu: @escaping () -> MenuContent
    ) -> some View {
        Menu {
            menu()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(IrfaaliTheme.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(IrfaaliTheme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isProcessing)
    }

    private var enhancementControls: some View {
        VStack(spacing: 13) {
            enhancementSlider(icon: "drop.degreesign", ar: "تنظيف التشويش", en: "Noise Cleanup", keyPath: \VideoEnhancementSettings.denoise)
            enhancementSlider(icon: "viewfinder", ar: "استرجاع التفاصيل", en: "Detail Recovery", keyPath: \VideoEnhancementSettings.detailRecovery)
            enhancementSlider(icon: "scope", ar: "الحدة", en: "Sharpening", keyPath: \VideoEnhancementSettings.sharpening)
            enhancementSlider(icon: "circle.lefthalf.filled", ar: "حيوية اللون", en: "Color Boost", keyPath: \VideoEnhancementSettings.colorBoost)

            Text(
                preferences.text(
                    ar: "استخدم مستويات خفيفة للمحافظة على مظهر طبيعي.",
                    en: "Use light levels to keep the image natural."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func enhancementSlider(
        icon: String,
        ar: String,
        en: String,
        keyPath: WritableKeyPath<VideoEnhancementSettings, Double>
    ) -> some View {
        let value = model.enhancement[keyPath: keyPath]

        return VStack(spacing: 7) {
            HStack {
                Label(preferences.text(ar: ar, en: en), systemImage: icon)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(Int((value * 100).rounded()))%")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(IrfaaliTheme.accent)
            }

            Slider(
                value: Binding(
                    get: { model.enhancement[keyPath: keyPath] },
                    set: { model.updateEnhancement(keyPath, value: $0) }
                ),
                in: 0...1
            )
            .tint(IrfaaliTheme.accent)
            .disabled(model.isProcessing)
        }
    }

    private func outputSummary(_ info: VideoAssetInfo) -> some View {
        let size = model.settings.targetSize(for: info)
        let fps = model.settings.frameRate.requestedFPS ?? info.sourceFPS
        let codec = model.settings.codec.title(isArabic: preferences.isArabic)

        return HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(IrfaaliTheme.accent)
                .frame(width: 32, height: 32)
                .background(IrfaaliTheme.accent.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(preferences.text(ar: "الناتج المتوقع", en: "Expected output"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("\(Int(size.width))×\(Int(size.height)) · \(IrfaaliFormatters.fps(fps))")
                    .font(.headline.monospacedDigit())
                Text(codec)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var processingProgress: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 11) {
                ZStack {
                    Circle()
                        .stroke(IrfaaliTheme.accent.opacity(0.16), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: max(0.04, model.progress))
                        .stroke(IrfaaliTheme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: processingStageIcon)
                        .font(.caption.bold())
                        .foregroundStyle(IrfaaliTheme.accent)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(preferences.text(ar: model.processingStageTextArabic, en: model.processingStageTextEnglish))
                        .font(.subheadline.bold())
                    Text(processingStageCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text("\(Int(model.progress * 100))%")
                    .font(.headline.monospacedDigit().bold())
                    .foregroundStyle(IrfaaliTheme.accent)
            }

            ProgressView(value: model.progress)
                .tint(IrfaaliTheme.accent)

            Text(
                preferences.text(
                    ar: "نراجع خصائص الملف النهائي قبل اعتماده.",
                    en: "The final file is checked before it is accepted."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if model.canCancelProcessing {
                Button {
                    model.cancelProcessing()
                } label: {
                    Label(
                        preferences.text(ar: "إلغاء المعالجة", en: "Cancel Processing"),
                        systemImage: "xmark.circle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PremiumDestructiveButtonStyle())
            }
        }
        .padding(13)
        .background(IrfaaliTheme.accent.opacity(0.065), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var processingStageIcon: String {
        switch model.processingStage {
        case .idle: return "circle"
        case .preparing: return "gearshape.2"
        case .exporting: return "film.stack"
        case .generatingFrames: return "film.stack"
        case .enhancing: return "wand.and.rays"
        case .verifying: return "checkmark.shield"
        case .complete: return "checkmark.seal"
        }
    }

    private var processingStageCaption: String {
        switch model.processingStage {
        case .idle:
            return preferences.text(ar: "جاهز للبدء", en: "Ready to start")
        case .preparing:
            return preferences.text(ar: "تجهيز المسارات والملف", en: "Preparing tracks and output")
        case .exporting:
            return preferences.text(ar: "تطبيق الدقة والترميز", en: "Applying resolution and codec")
        case .generatingFrames:
            return preferences.text(ar: "تجهيز الفريمات", en: "Preparing frames")
        case .enhancing:
            return preferences.text(ar: "تحسين كل فريم", en: "Enhancing each frame")
        case .verifying:
            return preferences.text(ar: "قراءة الناتج من جديد", en: "Reading the output again")
        case .complete:
            return preferences.text(ar: "تم اعتماد الملف", en: "Output accepted")
        }
    }

    private func processingSummary(_ info: VideoAssetInfo) -> String {
        let size = model.settings.targetSize(for: info)
        let fps = model.settings.frameRate.requestedFPS ?? info.sourceFPS
        let base = "\(Int(size.width))×\(Int(size.height)) · \(IrfaaliFormatters.fps(fps)) · \(model.settings.codec.title(isArabic: preferences.isArabic))"
        guard model.enhancement.isEnabled else { return base }
        return "\(base) · \(model.enhancement.mode.title(isArabic: preferences.isArabic))"
    }

    private func successCard(_ outcome: ExportOutcome) -> some View {
        let output = model.outputInfo
        let outputFPS = output?.sourceFPS ?? outcome.outputFPS
        let fpsText: String
        if outcome.fpsMode == .retimed {
            fpsText = preferences.text(
                ar: "تم تحويل الفريمات إلى \(IrfaaliFormatters.fps(outputFPS)) مع الحفاظ على ترتيبها.",
                en: "Frames were retimed to \(IrfaaliFormatters.fps(outputFPS)) while preserving their order."
            )
        } else {
            fpsText = preferences.text(
                ar: "الفريمات محفوظة عند \(IrfaaliFormatters.fps(outputFPS)).",
                en: "The source cadence is preserved at \(IrfaaliFormatters.fps(outputFPS))."
            )
        }

        return PremiumSurface {
            VStack(alignment: .leading, spacing: 14) {
                Label(
                    preferences.text(ar: "تم تجهيز الفيديو", en: "Video ready"),
                    systemImage: "checkmark.seal.fill"
                )
                .font(.headline.bold())
                .foregroundStyle(IrfaaliTheme.accent)

                Text(fpsText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let source = model.info, let output {
                    HStack(spacing: 9) {
                        ComparisonColumn(
                            title: preferences.text(ar: "قبل", en: "Before"),
                            resolution: "\(source.width)×\(source.height)",
                            fps: IrfaaliFormatters.fps(source.sourceFPS),
                            codec: source.videoCodec
                        )
                        ComparisonColumn(
                            title: preferences.text(ar: "بعد", en: "After"),
                            resolution: "\(output.width)×\(output.height)",
                            fps: IrfaaliFormatters.fps(output.sourceFPS),
                            codec: output.videoCodec
                        )
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        Task { await model.saveOutputToPhotos() }
                    } label: {
                        saveButtonLabel
                    }
                    .buttonStyle(PremiumPrimaryButtonStyle())
                    .disabled(model.saveState == .saving || model.saveState == .saved)

                    ShareLink(item: outcome.url) {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(PremiumSecondaryButtonStyle())
                }

                if case .failed(let message) = model.saveState {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    @ViewBuilder
    private var saveButtonLabel: some View {
        switch model.saveState {
        case .idle:
            Label(preferences.text(ar: "حفظ في الصور", en: "Save to Photos"), systemImage: "square.and.arrow.down")
                .frame(maxWidth: .infinity)
        case .saving:
            HStack {
                ProgressView()
                Text(preferences.text(ar: "جارٍ الحفظ…", en: "Saving…"))
            }
            .frame(maxWidth: .infinity)
        case .saved:
            Label(preferences.text(ar: "تم الحفظ", en: "Saved"), systemImage: "checkmark")
                .frame(maxWidth: .infinity)
        case .failed:
            Label(preferences.text(ar: "إعادة الحفظ", en: "Try Again"), systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
        }
    }

    private func audioSummary(_ info: VideoAssetInfo) -> String {
        guard let codec = info.audioCodec else {
            return preferences.text(ar: "بدون صوت", en: "No audio")
        }

        let channels = info.audioChannels.map { "\($0)ch" } ?? ""
        let rate = info.audioSampleRate.map { String(format: "%.1fkHz", $0 / 1000) } ?? ""
        return [codec, channels, rate]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func statusCard(_ message: String, icon: String, color: Color) -> some View {
        PremiumSurface {
            Label(message, systemImage: icon)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SourceMetric: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(IrfaaliTheme.accent)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

private struct ComparisonColumn: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let resolution: String
    let fps: String
    let codec: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(IrfaaliTheme.accent)
            Text(resolution)
                .font(.subheadline.bold())
            Text(fps)
                .font(.caption.monospacedDigit())
            Text(codec)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(
            colorScheme == .dark ? Color.white.opacity(0.045) : Color.black.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }
}

private struct PremiumPrimaryButtonStyle: ButtonStyle {
    @EnvironmentObject private var preferences: AppPreferences

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(
                IrfaaliTheme.accent.opacity(configuration.isPressed ? 0.74 : 0.96),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .foregroundStyle(Color.black)
            .scaleEffect(configuration.isPressed && preferences.animationsEnabled ? 0.98 : 1)
            .animation(.easeOut(duration: preferences.animationsEnabled ? 0.14 : 0), value: configuration.isPressed)
    }
}

private struct PremiumSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: AppPreferences

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .padding(.horizontal, 13)
            .frame(minHeight: 48)
            .background(
                colorScheme == .dark
                    ? Color.white.opacity(configuration.isPressed ? 0.10 : 0.055)
                    : Color.white.opacity(configuration.isPressed ? 0.92 : 0.76),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(colorScheme == .dark ? .white.opacity(0.11) : .black.opacity(0.08), lineWidth: 1)
            }
            .foregroundStyle(.primary)
            .scaleEffect(configuration.isPressed && preferences.animationsEnabled ? 0.98 : 1)
    }
}

private struct PremiumDestructiveButtonStyle: ButtonStyle {
    @EnvironmentObject private var preferences: AppPreferences

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(
                Color.red.opacity(configuration.isPressed ? 0.16 : 0.08),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.red.opacity(configuration.isPressed ? 0.42 : 0.22), lineWidth: 1)
            }
            .foregroundStyle(.red)
            .scaleEffect(configuration.isPressed && preferences.animationsEnabled ? 0.98 : 1)
            .animation(.easeOut(duration: preferences.animationsEnabled ? 0.14 : 0), value: configuration.isPressed)
    }
}
