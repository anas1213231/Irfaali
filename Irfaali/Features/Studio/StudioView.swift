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
    @State private var showOriginal = false
    @State private var previewExport = false
    @Namespace private var presetSelection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var preferences: AppPreferences

    init(model: StudioViewModel? = nil) {
        _model = StateObject(wrappedValue: model ?? StudioViewModel())
    }

    var body: some View {
        ZStack {
            ThemeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if model.info == nil {
                        studioIntro
                        importCard
                    }

                    if model.isAnalyzing {
                        analyzingCard
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if let info = model.info {
                        previewCard(info)
                        processingCard(info)
                        DisclosureGroup(preferences.text(ar: "معلومات المصدر", en: "Source information")) {
                            sourceCard(info)
                            importCard
                        }
                        .font(.subheadline)
                        .tint(IrfaaliTheme.accent)
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
        .foregroundStyle(.white)
        .navigationTitle(preferences.text(ar: "ارفعلي", en: "Irfaali"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.info != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(selection: $photoItem, matching: .videos) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .accessibilityLabel(preferences.text(ar: "تغيير الفيديو", en: "Change video"))
                    .disabled(model.isProcessing || model.isAnalyzing)
                }
            }
        }
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
        .onChange(of: preferences.language, initial: true) { _, _ in
            model.isArabic = preferences.isArabic
        }
        .onChange(of: model.info?.url) { _, _ in
            showOriginal = false
            previewExport = false
        }
        .onChange(of: model.lastOutcome?.url) { _, value in
            if value != nil { previewExport = true }
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
                    model.errorMessage = AppErrorMessage.describe(error, isArabic: preferences.isArabic)
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
                        model.errorMessage = AppErrorMessage.describe(error, isArabic: preferences.isArabic)
                    }
                }
            case .failure(let error):
                model.errorMessage = AppErrorMessage.describe(error, isArabic: preferences.isArabic)
            }
        }
    }

    private var studioIntro: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(preferences.text(ar: "كل لقطة.\nبشكل أفضل.", en: "Every frame.\nRefined."))
                .font(.system(size: 40, weight: .bold))
                .tracking(preferences.isArabic ? 0 : -1.5)
                .fixedSize(horizontal: false, vertical: true)
            Text(preferences.text(ar: "عدّل الإضاءة والتفاصيل، وشاهد النتيجة قبل التصدير.", en: "Shape the light and detail. See your adjustments before exporting."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 12)
    }

    private var importCard: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $photoItem, matching: .videos) {
                HStack(spacing: 12) {
                    Image(systemName: model.info == nil ? "plus" : "arrow.triangle.2.circlepath")
                        .font(.title3.weight(.medium))
                    Text(preferences.text(ar: model.info == nil ? "أضف الفيديو" : "تغيير الفيديو", en: model.info == nil ? "Add video" : "Change video"))
                        .font(.headline)
                    Spacer()
                    Image(systemName: "photo.on.rectangle")
                }
                .padding(.vertical, model.info == nil ? 12 : 0)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PremiumPrimaryButtonStyle())
            Button { showFileImporter = true } label: {
                Label(preferences.text(ar: "اختيار من الملفات", en: "Choose from Files"), systemImage: "folder")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .disabled(model.isAnalyzing || model.isProcessing)
    }

    private func previewCard(_ info: VideoAssetInfo) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(preferences.text(ar: "المعاينة", en: "Preview"))
                    .font(.headline)
                Spacer()
                if model.lastOutcome != nil {
                    Button {
                        previewExport.toggle()
                    } label: {
                        Text(preferences.text(ar: previewExport ? "عرض التعديل" : "عرض الملف الناتج", en: previewExport ? "Show adjustments" : "Show export"))
                            .font(.caption.weight(.semibold))
                    }
                }
            }
            Group {
                if model.isProcessing {
                    ZStack {
                        VideoThumbnailView(url: info.url, isAvailable: true)
                        Color.black.opacity(0.45)
                        VStack(spacing: 12) {
                            ProgressView().tint(.white)
                            Text(preferences.text(ar: model.processingStageTextArabic, en: model.processingStageTextEnglish))
                                .font(.headline).foregroundStyle(.white)
                            Text("\(Int(model.progress * 100))%")
                                .monospacedDigit().foregroundStyle(.white)
                                .contentTransition(.numericText())
                        }
                    }
                } else {
                    VideoCanvas(
                        url: previewExport ? (model.lastOutcome?.url ?? info.url) : info.url,
                        enhancement: previewExport || showOriginal ? .off : model.enhancement
                    )
                }
            }
            .frame(height: info.height > info.width ? 330 : 230)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(alignment: .topLeading) {
                Text(preferences.text(ar: previewExport ? "الناتج" : (showOriginal ? "الأصل" : "التعديل"), en: previewExport ? "EXPORTED" : (showOriginal ? "ORIGINAL" : "ADJUSTED")))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.14), lineWidth: 0.5)
                    }
                    .padding(12)
            }
            if !previewExport && !model.isProcessing {
                Picker(preferences.text(ar: "المقارنة", en: "Compare"), selection: $showOriginal) {
                    Text(preferences.text(ar: "الأصل", en: "Original")).tag(true)
                    Text(preferences.text(ar: "التعديل", en: "Adjusted")).tag(false)
                }
                .pickerStyle(.segmented)
                Text(preferences.text(ar: "معاينة الألوان والتفاصيل مباشرة. الدقة والفريمات تُطبّق عند التصدير.", en: "Live color and detail preview. Resolution and frame rate are applied on export."))
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var adjustmentPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(VideoEnhancementSettings.Mode.allCases.filter { $0 != .custom }) { mode in
                        Button {
                            model.applyEnhancementMode(mode)
                            showOriginal = false
                            previewExport = false
                        } label: {
                            Text(mode.title(isArabic: preferences.isArabic))
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                .background {
                                    if model.enhancement.mode == mode {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(.ultraThinMaterial)
                                            .matchedGeometryEffect(id: "selectedPreset", in: presetSelection)
                                    } else {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(.ultraThinMaterial)
                                    }
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(.white.opacity(model.enhancement.mode == mode ? 0.22 : 0.10), lineWidth: 0.5)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            enhancementSlider(icon: "sun.max", ar: "الإضاءة", en: "Exposure", keyPath: \VideoEnhancementSettings.exposure, range: -1...1)
            enhancementSlider(icon: "circle.lefthalf.filled", ar: "التباين", en: "Contrast", keyPath: \VideoEnhancementSettings.contrast, range: -1...1)
            enhancementControls
        }
        .disabled(model.isProcessing)
        .animation(preferences.animationsEnabled && !reduceMotion ? .snappy(duration: 0.25) : nil, value: model.enhancement.mode)
        .sensoryFeedback(.selection, trigger: model.enhancement.mode) { _, _ in preferences.hapticsEnabled }
    }

    private var analyzingCard: some View {
        PremiumSurface {
            HStack(spacing: 13) {
                ProgressView()
                    .controlSize(.regular)
                    .tint(IrfaaliTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.14), lineWidth: 0.5)
                    }

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
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(.white.opacity(0.14), lineWidth: 0.5)
                        }
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
                .foregroundStyle(.white)
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
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(.white.opacity(0.14), lineWidth: 0.5)
                        }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(preferences.text(ar: "تعديل", en: "Edit"))
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

                VStack(alignment: .leading, spacing: 16) {
                    Label(preferences.text(ar: "تعديل الصورة", en: "Image adjustments"), systemImage: "slider.horizontal.3")
                        .font(.headline)
                    adjustmentPanel
                }
                .padding(.vertical, 20)

                Text(outputExplanation(info))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

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
                                    codec: finalInfo.videoCodec,
                                    duration: finalInfo.duration,
                                    fileSizeBytes: finalInfo.fileSizeBytes,
                                    estimatedBitrate: finalInfo.estimatedBitrate
                                )
                                modelContext.insert(record)
                                try? modelContext.save()
                            }
                        }
                    } label: {
                        HStack(spacing: 9) {
                            Text(preferences.text(ar: "معالجة الفيديو", en: "Process video"))
                            Spacer()
                            Image(systemName: preferences.isArabic ? "arrow.left" : "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PremiumProcessButtonStyle())
                    .disabled(model.isAnalyzing || model.isProcessing)
                    
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
                    .foregroundStyle(.white)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(model.isProcessing)
    }

    private var enhancementControls: some View {
        VStack(spacing: 13) {
            enhancementSlider(icon: "drop.degreesign", ar: "تنظيف التشويش", en: "Noise Cleanup", keyPath: \VideoEnhancementSettings.denoise)
            enhancementSlider(icon: "viewfinder", ar: "وضوح التفاصيل", en: "Detail", keyPath: \VideoEnhancementSettings.detailRecovery)
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 0.5)
        }
    }

    private func enhancementSlider(
        icon: String,
        ar: String,
        en: String,
        keyPath: WritableKeyPath<VideoEnhancementSettings, Double>,
        range: ClosedRange<Double> = 0...1
    ) -> some View {
        let value = model.enhancement[keyPath: keyPath]

        return VStack(spacing: 7) {
            HStack {
                Label(preferences.text(ar: ar, en: en), systemImage: icon)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(Int((value * 100).rounded()))%")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { model.enhancement[keyPath: keyPath] },
                    set: { model.updateEnhancement(keyPath, value: $0); showOriginal = false; previewExport = false }
                ),
                in: range
            )
            .tint(IrfaaliTheme.activeAccent)
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
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 0.5)
                }

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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 0.5)
        }
    }

    private var processingProgress: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 11) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.16), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: max(0.04, model.progress))
                        .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: processingStageIcon)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
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
                    .foregroundStyle(.white)
            }

            ProgressView(value: model.progress)
                .tint(.white)

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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 0.5)
        }
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

    private func outputExplanation(_ info: VideoAssetInfo) -> String {
        let target = model.settings.targetSize(for: info)
        let upscaled = max(target.width, target.height) > CGFloat(max(info.width, info.height))
        var parts: [String] = []
        if upscaled {
            parts.append(preferences.text(ar: "تكبير الدقة إلى \(Int(target.width))×\(Int(target.height)). لا يعيد تفاصيل غير موجودة في الأصل.", en: "Upscaled to \(Int(target.width))×\(Int(target.height)). This cannot restore detail missing from the source."))
        }
        if model.needsFrameGeneration {
            parts.append(preferences.text(ar: "توليد إطارات وسطية بتقدير الحركة؛ قد تظهر تشوهات حول الحركة السريعة.", en: "Motion interpolation creates intermediate frames; fast motion may show artifacts."))
            if model.frameGenerationReadiness?.canStart == false {
                parts.append(preferences.text(ar: "التوليد غير متاح بحالة الجهاز أو الدقة الحالية. قلل الدقة أو انتظر حتى يبرد الجهاز.", en: "Generation is unavailable with the current device conditions or size. Lower the resolution or let the device cool down."))
            }
        }
        return parts.joined(separator: "\n")
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
        if outcome.fpsMode == .interpolated {
            fpsText = preferences.text(ar: "تم توليد \(model.generatedFrameCount) إطار جديد للحركة عند \(IrfaaliFormatters.fps(outputFPS)).", en: "Generated \(model.generatedFrameCount) new motion frames at \(IrfaaliFormatters.fps(outputFPS)).")
        } else if outcome.fpsMode == .retimed {
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
                .foregroundStyle(.white)

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
                .foregroundStyle(.white)
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
                .foregroundStyle(.secondary)
            Text(resolution)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
            Text(fps)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white)
            Text(codec)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 0.5)
        }
    }
}

private struct PremiumPrimaryButtonStyle: ButtonStyle {
    @EnvironmentObject private var preferences: AppPreferences

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(configuration.isPressed ? 0.26 : 0.16), lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed && preferences.animationsEnabled ? 0.98 : 1)
            .animation(.easeOut(duration: preferences.animationsEnabled ? 0.14 : 0), value: configuration.isPressed)
    }
}

private struct PremiumProcessButtonStyle: ButtonStyle {
    @EnvironmentObject private var preferences: AppPreferences

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(
                IrfaaliTheme.activeAccent.opacity(configuration.isPressed ? 0.82 : 1),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(.white)
            .shadow(color: IrfaaliTheme.activeAccent.opacity(0.18), radius: 12, y: 5)
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(configuration.isPressed ? 0.22 : 0.14), lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(.white)
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.red.opacity(configuration.isPressed ? 0.42 : 0.28), lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(.red)
            .scaleEffect(configuration.isPressed && preferences.animationsEnabled ? 0.98 : 1)
            .animation(.easeOut(duration: preferences.animationsEnabled ? 0.14 : 0), value: configuration.isPressed)
    }
}
