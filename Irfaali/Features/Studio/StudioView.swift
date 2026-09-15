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
                VStack(alignment: .leading, spacing: 30) {
                    if model.info == nil {
                        studioIntro
                        importPortal
                    }

                    if model.isAnalyzing {
                        analyzingPanel
                            .transition(.opacity)
                    }

                    if let info = model.info {
                        previewStage(info)
                        processingCard(info)
                        sourceDisclosure(info)
                    }

                    if let outcome = model.lastOutcome {
                        successCard(outcome)
                            .transition(.opacity)
                    }

                    if let message = model.validationMessage {
                        statusStrip(message, icon: "exclamationmark.triangle.fill", color: .orange)
                            .transition(.opacity)
                    }

                    if let message = model.errorMessage {
                        statusStrip(message, icon: "exclamationmark.octagon.fill", color: .red)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, model.info == nil ? 18 : 8)
                .padding(.bottom, 44)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 8)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.white)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.info != nil {
                ToolbarItem(placement: .principal) {
                    Image("OfficialLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 30)
                        .accessibilityLabel(AppBranding.appName)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(selection: $photoItem, matching: .videos) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(VIPPlainButtonStyle())
                    .accessibilityLabel(preferences.text(ar: "تغيير الفيديو", en: "Change video"))
                    .disabled(model.isProcessing || model.isAnalyzing)
                }
            }
        }
        .animation(preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.15) : nil, value: model.info?.url)
        .animation(preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.15) : nil, value: model.isAnalyzing)
        .animation(preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.15) : nil, value: model.isProcessing)
        .animation(preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.15) : nil, value: model.lastOutcome?.url)
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
                withAnimation(.easeOut(duration: 0.28)) {
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
        VStack(alignment: .leading, spacing: 0) {
            Image("OfficialLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
                .accessibilityLabel(AppBranding.appName)
                .padding(.bottom, 24)

            Text(AppBranding.appName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            Text(preferences.text(ar: "كل لقطة.\nبشكل أفضل.", en: "Every frame.\nRefined."))
                .font(.system(size: 46, weight: .bold))
                .tracking(preferences.isArabic ? 0 : -1.7)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 14)

            Text(
                preferences.text(
                    ar: "ارفع فيديو، واضبطه بطريقتك.",
                    en: "Bring in a video. Make every frame yours."
                )
            )
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var importPortal: some View {
        VStack(spacing: 14) {
            PhotosPicker(selection: $photoItem, matching: .videos) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(IrfaaliVisual.electricCyan.opacity(0.10))
                            .frame(width: 54, height: 54)

                        Circle()
                            .stroke(IrfaaliVisual.electricCyan.opacity(0.42), lineWidth: 0.8)
                            .frame(width: 54, height: 54)

                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(IrfaaliVisual.electricCyan)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(preferences.text(ar: "ارفع فيديو", en: "Bring in a video"))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)

                        Text(preferences.text(ar: "من مكتبة الصور", en: "From your photo library"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: preferences.isArabic ? "arrow.left" : "arrow.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 96)
            }
            .buttonStyle(ImportPortalButtonStyle())

            Button { showFileImporter = true } label: {
                Label(
                    preferences.text(ar: "أو اختره من الملفات", en: "Or choose from Files"),
                    systemImage: "folder"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(VIPPlainButtonStyle())
        }
        .disabled(model.isAnalyzing || model.isProcessing)
    }

    private var analyzingPanel: some View {
        HStack(spacing: 14) {
            IrfaaliMiniActivity()

            VStack(alignment: .leading, spacing: 3) {
                Text(preferences.text(ar: "نقرأ الفيديو", en: "Reading your video"))
                    .font(.headline.weight(.bold))

                Text(preferences.text(ar: "الدقة · الفريمات · الترميز · الصوت", en: "Resolution · frame rate · codec · audio"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            IrfaaliHairline()
        }
    }

    private func previewStage(_ info: VideoAssetInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preferences.text(ar: "الفيديو", en: "Video"))
                        .font(.system(size: 24, weight: .bold))
                    Text("\(info.width)×\(info.height) · \(IrfaaliFormatters.fps(info.sourceFPS))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if model.lastOutcome != nil {
                    Button {
                        previewExport.toggle()
                    } label: {
                        Text(
                            preferences.text(
                                ar: previewExport ? "عرض التعديل" : "عرض الناتج",
                                en: previewExport ? "Adjustments" : "Export"
                            )
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(previewExport ? IrfaaliVisual.electricCyan : .white)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 34)
                        .background(IrfaaliVisual.quietFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(VIPPlainButtonStyle())
                }
            }

            Group {
                if model.isProcessing {
                    ZStack {
                        VideoThumbnailView(url: info.url, isAvailable: true)
                            .overlay(Color.black.opacity(0.70))

                        VStack(spacing: 10) {
                            IrfaaliProcessingGlyph(progress: model.progress)

                            Text(preferences.text(ar: model.processingStageTextArabic, en: model.processingStageTextEnglish))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)

                            Text("\(Int(model.progress * 100))%")
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                        .padding(.vertical, 12)
                    }
                } else {
                    VideoCanvas(
                        url: previewExport ? (model.lastOutcome?.url ?? info.url) : info.url,
                        enhancement: previewExport || showOriginal ? .off : model.enhancement
                    )
                }
            }
            .frame(height: info.height > info.width ? 360 : 238)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.11), lineWidth: 0.5)
            }
            .overlay(alignment: .topLeading) {
                Text(
                    preferences.text(
                        ar: previewExport ? "الناتج" : (showOriginal ? "الأصل" : "التعديل"),
                        en: previewExport ? "EXPORT" : (showOriginal ? "ORIGINAL" : "ADJUSTED")
                    )
                )
                .font(.caption2.weight(.bold))
                .tracking(preferences.isArabic ? 0 : 1.0)
                .foregroundStyle(.white.opacity(0.90))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.66), in: Capsule())
                .padding(12)
            }

            if !previewExport && !model.isProcessing {
                compareControl

                Text(
                    preferences.text(
                        ar: "معاينة اللون والتفاصيل مباشرة.",
                        en: "Preview color and detail changes live."
                    )
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
    }

    private var compareControl: some View {
        HStack(spacing: 4) {
            compareButton(
                title: preferences.text(ar: "الأصل", en: "Original"),
                selected: showOriginal
            ) {
                showOriginal = true
            }

            compareButton(
                title: preferences.text(ar: "التعديل", en: "Adjusted"),
                selected: !showOriginal
            ) {
                showOriginal = false
            }
        }
        .padding(3)
        .background(IrfaaliVisual.quieterFill, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(IrfaaliVisual.hairline, lineWidth: 0.5)
        }
        .sensoryFeedback(.selection, trigger: showOriginal) { oldValue, newValue in
            preferences.hapticsEnabled && oldValue != newValue
        }
    }

    private func compareButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? .white : .secondary)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(
                    selected ? Color.white.opacity(0.085) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
        }
        .buttonStyle(VIPPlainButtonStyle())
    }

    private func processingCard(_ info: VideoAssetInfo) -> some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .center) {
                IrfaaliSectionHeading(
                    title: preferences.text(ar: "جهّز النتيجة", en: "Build the result"),
                    detail: preferences.text(ar: "الأهم أولًا. والباقي وقت ما تحتاجه.", en: "The essentials first. Fine-tune only when you need it.")
                )

                Button {
                    withAnimation(preferences.animationsEnabled ? .easeInOut(duration: 0.15) : nil) {
                        model.applyRecommendedSettings()
                    }
                } label: {
                    Text(preferences.text(ar: "موصى به", en: "Recommended"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(IrfaaliVisual.electricCyan)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 34)
                        .background(IrfaaliVisual.electricCyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(VIPPlainButtonStyle())
                .disabled(model.isProcessing)
            }

            resolutionSelector(info)
            frameRateSelector(info)
            codecSelector
            adjustmentDisclosure

            outputSummary(info)

            let explanation = outputExplanation(info)
            if !explanation.isEmpty {
                DisclosureGroup {
                    Text(explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                } label: {
                    Text(preferences.text(ar: "ملاحظات التصدير", en: "Export notes"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .tint(.secondary)
            }

            if model.isProcessing {
                processingProgress
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
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(preferences.text(ar: "معالجة الفيديو", en: "Process video"))
                                .font(.headline.weight(.bold))
                            Text(processingSummary(info))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.58))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }

                        Spacer(minLength: 8)

                        ZStack {
                            Circle()
                                .fill(IrfaaliVisual.electricCyan.opacity(0.13))
                                .frame(width: 42, height: 42)
                            Image(systemName: preferences.isArabic ? "arrow.left" : "arrow.right")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(IrfaaliVisual.electricCyan)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PremiumProcessButtonStyle())
                .disabled(model.isAnalyzing || model.isProcessing)
            }
        }
    }

    private func resolutionSelector(_ info: VideoAssetInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            selectorHeader(
                index: "01",
                title: preferences.text(ar: "الجودة", en: "Quality"),
                value: model.settings.resolution.title(isArabic: preferences.isArabic)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(VideoProcessingSettings.supportedResolutions(for: info)) { resolution in
                        selectionButton(
                            title: resolution.title(isArabic: preferences.isArabic),
                            selected: model.settings.resolution == resolution
                        ) {
                            model.settings.resolution = resolution
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .disabled(model.isProcessing)
        .sensoryFeedback(.selection, trigger: model.settings.resolution.id) { oldValue, newValue in
            preferences.hapticsEnabled && oldValue != newValue
        }
    }

    private func frameRateSelector(_ info: VideoAssetInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            selectorHeader(
                index: "02",
                title: preferences.text(ar: "الفريمات", en: "Frame rate"),
                value: model.settings.frameRate.title(isArabic: preferences.isArabic)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(VideoProcessingSettings.supportedFrameRates(for: info)) { frameRate in
                        selectionButton(
                            title: frameRate.title(isArabic: preferences.isArabic),
                            selected: model.settings.frameRate == frameRate
                        ) {
                            model.settings.frameRate = frameRate
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .disabled(model.isProcessing)
        .sensoryFeedback(.selection, trigger: model.settings.frameRate.id) { oldValue, newValue in
            preferences.hapticsEnabled && oldValue != newValue
        }
    }

    private var codecSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            selectorHeader(
                index: "03",
                title: preferences.text(ar: "الترميز", en: "Encoding"),
                value: model.settings.codec.title(isArabic: preferences.isArabic)
            )

            HStack(spacing: 8) {
                ForEach(VideoProcessingSettings.Codec.allCases) { codec in
                    selectionButton(
                        title: codec.title(isArabic: preferences.isArabic),
                        selected: model.settings.codec == codec
                    ) {
                        model.settings.codec = codec
                    }
                }
            }
        }
        .disabled(model.isProcessing)
        .sensoryFeedback(.selection, trigger: model.settings.codec.id) { oldValue, newValue in
            preferences.hapticsEnabled && oldValue != newValue
        }
    }

    private func selectorHeader(index: String, title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(index)
                .font(.caption2.monospacedDigit().weight(.bold))
                .foregroundStyle(IrfaaliVisual.electricCyan)

            Text(title)
                .font(.headline.weight(.bold))

            Spacer()

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func selectionButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(selected ? .bold : .semibold))
                .foregroundStyle(selected ? .white : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .padding(.horizontal, 15)
                .frame(minWidth: 72, minHeight: 42)
                .background {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(selected ? IrfaaliVisual.electricCyan.opacity(0.10) : IrfaaliVisual.quieterFill)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(
                            selected ? IrfaaliVisual.electricCyan.opacity(0.42) : IrfaaliVisual.hairline,
                            lineWidth: selected ? 0.9 : 0.5
                        )
                }
        }
        .buttonStyle(VIPPlainButtonStyle())
    }

    private var adjustmentDisclosure: some View {
        DisclosureGroup {
            adjustmentPanel
                .padding(.top, 18)
        } label: {
            HStack(spacing: 12) {
                Text("04")
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(IrfaaliVisual.electricCyan)

                VStack(alignment: .leading, spacing: 3) {
                    Text(preferences.text(ar: "تحسين الصورة", en: "Enhancement"))
                        .font(.headline.weight(.bold))
                    Text(model.enhancement.mode.title(isArabic: preferences.isArabic))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 6)
        }
        .tint(.secondary)
        .overlay(alignment: .top) {
            IrfaaliHairline()
                .offset(y: -12)
        }
    }

    private var adjustmentPanel: some View {
        VStack(alignment: .leading, spacing: 22) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(VideoEnhancementSettings.Mode.allCases.filter { $0 != .custom }) { mode in
                        Button {
                            model.applyEnhancementMode(mode)
                            showOriginal = false
                            previewExport = false
                        } label: {
                            VStack(spacing: 7) {
                                Text(mode.title(isArabic: preferences.isArabic))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(model.enhancement.mode == mode ? .white : .secondary)

                                Capsule()
                                    .fill(model.enhancement.mode == mode ? IrfaaliVisual.electricCyan : Color.clear)
                                    .frame(width: 24, height: 2)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(VIPPlainButtonStyle())
                    }
                }
            }

            enhancementSlider(icon: "sun.max", ar: "الإضاءة", en: "Exposure", keyPath: \VideoEnhancementSettings.exposure, range: -1...1)
            enhancementSlider(icon: "circle.lefthalf.filled", ar: "التباين", en: "Contrast", keyPath: \VideoEnhancementSettings.contrast, range: -1...1)
            enhancementControls
        }
        .disabled(model.isProcessing)
        .animation(preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.15) : nil, value: model.enhancement.mode)
        .sensoryFeedback(.selection, trigger: model.enhancement.mode) { _, _ in preferences.hapticsEnabled }
    }

    private var enhancementControls: some View {
        VStack(spacing: 18) {
            enhancementSlider(icon: "drop.degreesign", ar: "تنظيف التشويش", en: "Noise Cleanup", keyPath: \VideoEnhancementSettings.denoise)
            enhancementSlider(icon: "viewfinder", ar: "وضوح التفاصيل", en: "Detail", keyPath: \VideoEnhancementSettings.detailRecovery)
            enhancementSlider(icon: "scope", ar: "الحدة", en: "Sharpening", keyPath: \VideoEnhancementSettings.sharpening)
            enhancementSlider(icon: "circle.lefthalf.filled", ar: "حيوية اللون", en: "Color Boost", keyPath: \VideoEnhancementSettings.colorBoost)

            Text(
                preferences.text(
                    ar: "خفيف أحسن. خل الصورة طبيعية.",
                    en: "Keep it light for a natural result."
                )
            )
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
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

        return VStack(spacing: 10) {
            HStack {
                Label(preferences.text(ar: ar, en: en), systemImage: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int((value * 100).rounded()))%")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white)
            }

            PrecisionSlider(
                value: Binding(
                    get: { model.enhancement[keyPath: keyPath] },
                    set: {
                        model.updateEnhancement(keyPath, value: $0)
                        showOriginal = false
                        previewExport = false
                    }
                ),
                range: range
            )
            .disabled(model.isProcessing)
        }
    }

    private func sourceDisclosure(_ info: VideoAssetInfo) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 20) {
                sourceCard(info)
                compactSourceReplacement
            }
            .padding(.top, 18)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(preferences.text(ar: "معلومات المصدر", en: "Source information"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(info.fileName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.vertical, 6)
        }
        .tint(.secondary)
        .overlay(alignment: .top) {
            IrfaaliHairline()
                .offset(y: -12)
        }
    }

    private func sourceCard(_ info: VideoAssetInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
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

            IrfaaliHairline()

            DisclosureGroup(
                preferences.text(ar: "التفاصيل", en: "Details"),
                isExpanded: $showSourceDetails
            ) {
                VStack(spacing: 11) {
                    detailRow(icon: "film.stack", title: preferences.text(ar: "الترميز", en: "Video Codec"), value: info.videoCodec)
                    detailRow(icon: "waveform", title: preferences.text(ar: "البت ريت", en: "Bitrate"), value: IrfaaliFormatters.bitrate(info.estimatedBitrate))
                    detailRow(icon: "clock", title: preferences.text(ar: "المدة", en: "Duration"), value: IrfaaliFormatters.duration(info.duration))
                    detailRow(icon: "speaker.wave.2", title: preferences.text(ar: "الصوت", en: "Audio"), value: audioSummary(info))
                    detailRow(icon: "shippingbox", title: preferences.text(ar: "الحاوية", en: "Container"), value: info.container)
                }
                .padding(.top, 12)
            }
            .font(.subheadline.weight(.semibold))
            .tint(.secondary)
        }
    }

    private var compactSourceReplacement: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $photoItem, matching: .videos) {
                Label(preferences.text(ar: "تغيير", en: "Change"), systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(PremiumSecondaryButtonStyle())

            Button { showFileImporter = true } label: {
                Label(preferences.text(ar: "ملفات", en: "Files"), systemImage: "folder")
                    .frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(PremiumSecondaryButtonStyle())
        }
        .disabled(model.isAnalyzing || model.isProcessing)
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func outputSummary(_ info: VideoAssetInfo) -> some View {
        let size = model.settings.targetSize(for: info)
        let fps = model.settings.frameRate.requestedFPS ?? info.sourceFPS
        let codec = model.settings.codec.title(isArabic: preferences.isArabic)

        return HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(preferences.text(ar: "الناتج", en: "Output"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(IrfaaliVisual.electricCyan)

                Text("\(Int(size.width))×\(Int(size.height))")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text("\(IrfaaliFormatters.fps(fps)) · \(codec)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.seal")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))
        }
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            IrfaaliHairline()
                .offset(y: -12)
        }
    }

    private var processingProgress: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(preferences.text(ar: model.processingStageTextArabic, en: model.processingStageTextEnglish))
                        .font(.headline.weight(.bold))
                    Text(processingStageCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(Int(model.progress * 100))%")
                    .font(.headline.monospacedDigit().weight(.bold))
                    .foregroundStyle(IrfaaliVisual.electricCyan)
                    .contentTransition(.numericText())
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(IrfaaliVisual.energyGradient)
                        .frame(width: max(3, proxy.size.width * model.progress))
                }
            }
            .frame(height: 3)

            if model.canCancelProcessing {
                Button {
                    model.cancelProcessing()
                } label: {
                    Label(
                        preferences.text(ar: "إلغاء المعالجة", en: "Cancel Processing"),
                        systemImage: "xmark"
                    )
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PremiumDestructiveButtonStyle())
            }
        }
        .padding(.top, 2)
    }

    private var processingStageCaption: String {
        switch model.processingStage {
        case .idle:
            return preferences.text(ar: "جاهز", en: "Ready")
        case .preparing:
            return preferences.text(ar: "تجهيز الفيديو", en: "Preparing video")
        case .exporting:
            return preferences.text(ar: "بناء النتيجة", en: "Building output")
        case .generatingFrames:
            return preferences.text(ar: "معالجة الإطارات", en: "Processing frames")
        case .enhancing:
            return preferences.text(ar: "تحسين التفاصيل", en: "Refining detail")
        case .verifying:
            return preferences.text(ar: "تجهيز النتيجة", en: "Finalizing")
        case .complete:
            return preferences.text(ar: "جاهز", en: "Ready")
        }
    }

    private func outputExplanation(_ info: VideoAssetInfo) -> String {
        let target = model.settings.targetSize(for: info)
        let upscaled = max(target.width, target.height) > CGFloat(max(info.width, info.height))
        var parts: [String] = []

        if upscaled {
            parts.append(
                preferences.text(
                    ar: "تكبير الدقة ما يقدر يرجّع تفاصيل غير موجودة في الأصل.",
                    en: "Upscaling cannot restore detail that is missing from the source."
                )
            )
        }

        if model.needsFrameGeneration {
            parts.append(
                preferences.text(
                    ar: "توليد الإطارات يعتمد على تقدير الحركة وقد يتأثر بالحركة السريعة.",
                    en: "Frame generation estimates motion and can be affected by very fast movement."
                )
            )

            if model.frameGenerationReadiness?.canStart == false {
                parts.append(
                    preferences.text(
                        ar: "التوليد غير متاح بحالة الجهاز أو الدقة الحالية.",
                        en: "Frame generation is unavailable with the current device conditions or size."
                    )
                )
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
            fpsText = preferences.text(
                ar: "تم توليد \(model.generatedFrameCount) إطار جديد عند \(IrfaaliFormatters.fps(outputFPS)).",
                en: "Generated \(model.generatedFrameCount) new motion frames at \(IrfaaliFormatters.fps(outputFPS))."
            )
        } else if outcome.fpsMode == .retimed {
            fpsText = preferences.text(
                ar: "تم تحويل الفريمات إلى \(IrfaaliFormatters.fps(outputFPS)).",
                en: "Frames were retimed to \(IrfaaliFormatters.fps(outputFPS))."
            )
        } else {
            fpsText = preferences.text(
                ar: "الفريمات محفوظة عند \(IrfaaliFormatters.fps(outputFPS)).",
                en: "Source cadence is preserved at \(IrfaaliFormatters.fps(outputFPS))."
            )
        }

        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(IrfaaliVisual.electricCyan.opacity(0.10))
                        .frame(width: 42, height: 42)
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(IrfaaliVisual.electricCyan)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(preferences.text(ar: "الفيديو جاهز", en: "Video ready"))
                        .font(.title3.weight(.bold))
                    Text(fpsText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let source = model.info, let output {
                HStack(spacing: 10) {
                    ComparisonColumn(
                        title: preferences.text(ar: "قبل", en: "Before"),
                        resolution: "\(source.width)×\(source.height)",
                        fps: IrfaaliFormatters.fps(source.sourceFPS),
                        codec: source.videoCodec
                    )

                    Image(systemName: preferences.isArabic ? "arrow.left" : "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)

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
        .padding(.top, 22)
        .overlay(alignment: .top) {
            IrfaaliHairline()
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

    private func statusStrip(_ message: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 22)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            IrfaaliHairline()
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
                .foregroundStyle(.secondary)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ComparisonColumn: View {
    let title: String
    let resolution: String
    let fps: String
    let codec: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)

            Text(resolution)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)

            Text(fps)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Text(codec)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }
}

private struct PrecisionSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    @Environment(\.layoutDirection) private var layoutDirection
    @EnvironmentObject private var preferences: AppPreferences
    @State private var isDragging = false

    private var normalized: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(max((value - range.lowerBound) / span, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let thumbSize: CGFloat = 18
            let usableWidth = max(1, proxy.size.width - thumbSize)
            let displayProgress = layoutDirection == .rightToLeft ? 1 - normalized : normalized
            let thumbX = CGFloat(displayProgress) * usableWidth

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.09))
                    .frame(height: 2)

                Capsule()
                    .fill(IrfaaliVisual.energyGradient)
                    .frame(width: max(2, thumbX + thumbSize / 2), height: 3)

                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay {
                        Circle()
                            .stroke(IrfaaliVisual.electricCyan.opacity(isDragging ? 0.65 : 0.20), lineWidth: 1)
                    }
                    .shadow(
                        color: IrfaaliVisual.electricCyan.opacity(isDragging ? 0.18 : 0),
                        radius: isDragging ? 8 : 0
                    )
                    .scaleEffect(isDragging ? 1.13 : 1)
                    .offset(x: thumbX)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let display = Double(min(max(gesture.location.x / max(proxy.size.width, 1), 0), 1))
                        let logical = layoutDirection == .rightToLeft ? 1 - display : display
                        value = range.lowerBound + logical * (range.upperBound - range.lowerBound)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: 30)
        .animation(.easeInOut(duration: 0.10), value: isDragging)
        .sensoryFeedback(.selection, trigger: Int((normalized * 50).rounded())) { oldValue, newValue in
            preferences.hapticsEnabled && isDragging && oldValue != newValue
        }
        .accessibilityElement()
        .accessibilityValue("\(Int((normalized * 100).rounded()))%")
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) / 20
            switch direction {
            case .increment:
                value = min(range.upperBound, value + step)
            case .decrement:
                value = max(range.lowerBound, value - step)
            @unknown default:
                break
            }
        }
    }
}

private struct ImportPortalButtonStyle: ButtonStyle {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.065 : 0.043))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                IrfaaliVisual.electricCyan.opacity(configuration.isPressed ? 0.55 : 0.34),
                                Color.white.opacity(0.12),
                                IrfaaliVisual.deepViolet.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
            .scaleEffect(configuration.isPressed && preferences.animationsEnabled && !reduceMotion ? 0.985 : 1)
            .animation(
                preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.10) : nil,
                value: configuration.isPressed
            )
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { oldValue, newValue in
                preferences.hapticsEnabled && !oldValue && newValue
            }
    }
}

private struct PremiumPrimaryButtonStyle: ButtonStyle {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Color.white.opacity(configuration.isPressed ? 0.12 : 0.08), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
            }
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed && preferences.animationsEnabled && !reduceMotion ? 0.98 : 1)
            .animation(
                preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.10) : nil,
                value: configuration.isPressed
            )
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { oldValue, newValue in
                preferences.hapticsEnabled && !oldValue && newValue
            }
    }
}

private struct PremiumProcessButtonStyle: ButtonStyle {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 17)
            .frame(minHeight: 70)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(configuration.isPressed ? 0.075 : 0.052))

                    LinearGradient(
                        colors: [
                            IrfaaliVisual.electricCyan.opacity(configuration.isPressed ? 0.12 : 0.08),
                            .clear,
                            IrfaaliVisual.deepViolet.opacity(0.045)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                IrfaaliVisual.electricCyan.opacity(0.48),
                                Color.white.opacity(0.12),
                                IrfaaliVisual.deepViolet.opacity(0.20)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 0.9
                    )
            }
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(IrfaaliVisual.energyGradient)
                    .frame(width: 3, height: 36)
                    .padding(.leading, 8)
            }
            .foregroundStyle(.white)
            .shadow(color: IrfaaliVisual.electricCyan.opacity(0.08), radius: 16, y: 6)
            .scaleEffect(configuration.isPressed && preferences.animationsEnabled && !reduceMotion ? 0.98 : 1)
            .animation(
                preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.10) : nil,
                value: configuration.isPressed
            )
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { oldValue, newValue in
                preferences.hapticsEnabled && !oldValue && newValue
            }
    }
}

private struct PremiumSecondaryButtonStyle: ButtonStyle {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(IrfaaliVisual.quieterFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(configuration.isPressed ? 0.18 : 0.10), lineWidth: 0.5)
            }
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed && preferences.animationsEnabled && !reduceMotion ? 0.98 : 1)
            .animation(
                preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.10) : nil,
                value: configuration.isPressed
            )
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { oldValue, newValue in
                preferences.hapticsEnabled && !oldValue && newValue
            }
    }
}

private struct PremiumDestructiveButtonStyle: ButtonStyle {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Color.red.opacity(configuration.isPressed ? 0.11 : 0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.red.opacity(0.24), lineWidth: 0.5)
            }
            .foregroundStyle(.red)
            .scaleEffect(configuration.isPressed && preferences.animationsEnabled && !reduceMotion ? 0.98 : 1)
            .animation(
                preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.10) : nil,
                value: configuration.isPressed
            )
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { oldValue, newValue in
                preferences.hapticsEnabled && !oldValue && newValue
            }
    }
}
