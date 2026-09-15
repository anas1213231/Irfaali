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
                VStack(alignment: .leading, spacing: model.info == nil ? 34 : 24) {
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
                        processingDeck(info)
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
                .padding(.horizontal, 20)
                .padding(.top, model.info == nil ? 24 : 10)
                .padding(.bottom, 52)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 6)
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
                        .frame(height: 28)
                        .accessibilityLabel(AppBranding.appName)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(selection: $photoItem, matching: .videos) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.subheadline.weight(.semibold))
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
                withAnimation(.easeOut(duration: 0.22)) {
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

    // MARK: - Opening composition

    private var studioIntro: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image("OfficialLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
                .accessibilityLabel(AppBranding.appName)
                .padding(.bottom, 26)

            Text(AppBranding.appName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            Text(preferences.text(ar: "كل لقطة.\nبشكل أفضل.", en: "Every frame.\nRefined."))
                .font(.system(size: 37, weight: .bold))
                .tracking(preferences.isArabic ? 0 : -1.2)
                .lineSpacing(preferences.isArabic ? 3 : 0)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 11)

            Text(preferences.text(ar: "ابدأ بالفيديو نفسه.", en: "Start with the video itself."))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var importPortal: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $photoItem, matching: .videos) {
                ZStack {
                    ImportGateMarks()

                    VStack(spacing: 13) {
                        Image(systemName: "plus")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(IrfaaliVisual.electricCyan)

                        VStack(spacing: 3) {
                            Text(preferences.text(ar: "اختر فيديو", en: "Choose a video"))
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)

                            Text(preferences.text(ar: "من مكتبة الصور", en: "From your photo library"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 132)
            }
            .buttonStyle(ImportPortalButtonStyle())

            Button { showFileImporter = true } label: {
                HStack(spacing: 7) {
                    Image(systemName: "folder")
                        .font(.caption.weight(.semibold))
                    Text(preferences.text(ar: "اختيار من الملفات", en: "Choose from Files"))
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(VIPPlainButtonStyle())
        }
        .disabled(model.isAnalyzing || model.isProcessing)
    }

    private var analyzingPanel: some View {
        HStack(spacing: 12) {
            IrfaaliMiniActivity()

            VStack(alignment: .leading, spacing: 3) {
                Text(preferences.text(ar: "قراءة الفيديو", en: "Reading video"))
                    .font(.subheadline.weight(.semibold))

                Text(preferences.text(ar: "الدقة · الفريمات · الترميز · الصوت", en: "Resolution · frame rate · codec · audio"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { IrfaaliHairline() }
    }

    // MARK: - Media stage

    private func previewStage(_ info: VideoAssetInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if model.isProcessing {
                    processingMediaStage(info)
                } else {
                    VideoCanvas(
                        url: previewExport ? (model.lastOutcome?.url ?? info.url) : info.url,
                        enhancement: previewExport || showOriginal ? .off : model.enhancement
                    )
                }
            }
            .frame(height: info.height > info.width ? 410 : 252)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                if !model.isProcessing {
                    mediaMetadata(info)
                }
            }

            if !previewExport && !model.isProcessing {
                compareControl
            } else if model.lastOutcome != nil && !model.isProcessing {
                Button {
                    previewExport.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Text(preferences.text(ar: previewExport ? "العودة للتعديل" : "عرض الناتج", en: previewExport ? "Back to adjustments" : "View export"))
                            .font(.caption.weight(.semibold))
                        Image(systemName: preferences.isArabic ? "arrow.left" : "arrow.right")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 36)
                }
                .buttonStyle(VIPPlainButtonStyle())
            }
        }
    }

    private func processingMediaStage(_ info: VideoAssetInfo) -> some View {
        ZStack {
            VideoThumbnailView(url: info.url, isAvailable: true)

            Color.black.opacity(0.20)

            GeometryReader { proxy in
                let progress = min(max(model.progress, 0), 1)
                let resolvedWidth = proxy.size.width * progress

                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: resolvedWidth)
                    Color.black.opacity(0.42)
                }

                Rectangle()
                    .fill(IrfaaliVisual.electricCyan.opacity(0.62))
                    .frame(width: 1)
                    .offset(x: max(0, min(proxy.size.width - 1, resolvedWidth)))
            }

            IrfaaliProcessingGlyph(progress: model.progress)

            VStack {
                Spacer()

                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(preferences.text(ar: model.processingStageTextArabic, en: model.processingStageTextEnglish))
                            .font(.subheadline.weight(.semibold))
                        Text(processingStageCaption)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(Int(model.progress * 100))%")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.76))
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
    }

    private func mediaMetadata(_ info: VideoAssetInfo) -> some View {
        LinearGradient(
            colors: [.clear, Color.black.opacity(0.76)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 86)
        .overlay(alignment: .bottomLeading) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(info.fileName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    Text("\(info.width)×\(info.height) · \(IrfaaliFormatters.fps(info.sourceFPS))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()

                Text(
                    preferences.text(
                        ar: previewExport ? "الناتج" : (showOriginal ? "الأصل" : "التعديل"),
                        en: previewExport ? "EXPORT" : (showOriginal ? "ORIGINAL" : "ADJUSTED")
                    )
                )
                .font(.caption2.weight(.semibold))
                .tracking(preferences.isArabic ? 0 : 0.8)
                .foregroundStyle(.white.opacity(0.72))
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .allowsHitTesting(false)
    }

    private var compareControl: some View {
        HStack(spacing: 22) {
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

            Spacer()
        }
        .sensoryFeedback(.selection, trigger: showOriginal) { oldValue, newValue in
            preferences.hapticsEnabled && oldValue != newValue
        }
    }

    private func compareButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(title)
                    .font(.caption.weight(selected ? .semibold : .medium))
                    .foregroundStyle(selected ? .white : .secondary)

                ZStack {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 1)

                    if selected {
                        Rectangle()
                            .fill(IrfaaliVisual.electricCyan)
                            .frame(height: 1)
                            .matchedGeometryEffect(id: "preview-mode", in: presetSelection)
                    }
                }
            }
        }
        .buttonStyle(VIPPlainButtonStyle())
    }

    // MARK: - Precision configuration

    private func processingDeck(_ info: VideoAssetInfo) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .firstTextBaseline) {
                Text(preferences.text(ar: "النتيجة", en: "Output"))
                    .font(.title3.weight(.semibold))

                Spacer()

                Button {
                    withAnimation(preferences.animationsEnabled ? .easeInOut(duration: 0.15) : nil) {
                        model.applyRecommendedSettings()
                    }
                } label: {
                    Text(preferences.text(ar: "موصى به", en: "Recommended"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(IrfaaliVisual.electricCyan)
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
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .tint(.secondary)
            }

            if model.isProcessing {
                processingProgress
            } else {
                processCommitAction(info)
            }
        }
    }

    private func resolutionSelector(_ info: VideoAssetInfo) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            controlHeading(
                preferences.text(ar: "الجودة", en: "Quality"),
                value: model.settings.resolution.title(isArabic: preferences.isArabic)
            )

            HStack(spacing: 0) {
                ForEach(VideoProcessingSettings.supportedResolutions(for: info)) { resolution in
                    let selected = model.settings.resolution == resolution

                    Button {
                        model.settings.resolution = resolution
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(resolution.title(isArabic: preferences.isArabic))
                                .font(.subheadline.monospacedDigit().weight(selected ? .bold : .medium))
                                .foregroundStyle(selected ? .white : .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)

                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.10))
                                    .frame(height: 0.5)

                                if selected {
                                    Rectangle()
                                        .fill(IrfaaliVisual.electricCyan)
                                        .frame(width: 22, height: 1)
                                        .matchedGeometryEffect(id: "resolution-selection", in: presetSelection)
                                }
                            }
                        }
                        .padding(.trailing, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(VIPPlainButtonStyle())
                }
            }
        }
        .disabled(model.isProcessing)
        .sensoryFeedback(.selection, trigger: model.settings.resolution.id) { oldValue, newValue in
            preferences.hapticsEnabled && oldValue != newValue
        }
    }

    private func frameRateSelector(_ info: VideoAssetInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            controlHeading(
                preferences.text(ar: "الحركة", en: "Frame rate"),
                value: model.settings.frameRate.title(isArabic: preferences.isArabic)
            )

            ZStack {
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 0.5)
                    .padding(.horizontal, 20)

                HStack(spacing: 0) {
                    ForEach(VideoProcessingSettings.supportedFrameRates(for: info)) { frameRate in
                        let selected = model.settings.frameRate == frameRate

                        Button {
                            model.settings.frameRate = frameRate
                        } label: {
                            VStack(spacing: 7) {
                                Rectangle()
                                    .fill(selected ? IrfaaliVisual.electricCyan : Color.white.opacity(0.28))
                                    .frame(width: selected ? 2 : 1, height: selected ? 16 : 9)
                                    .matchedGeometryEffect(
                                        id: selected ? "fps-selection" : "fps-\(frameRate.id)",
                                        in: presetSelection,
                                        isSource: true
                                    )

                                Text(frameRate.title(isArabic: preferences.isArabic))
                                    .font(.caption.monospacedDigit().weight(selected ? .bold : .medium))
                                    .foregroundStyle(selected ? .white : .secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(VIPPlainButtonStyle())
                    }
                }
            }
        }
        .disabled(model.isProcessing)
        .sensoryFeedback(.selection, trigger: model.settings.frameRate.id) { oldValue, newValue in
            preferences.hapticsEnabled && oldValue != newValue
        }
    }

    private var codecSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(preferences.text(ar: "الترميز", en: "Encoding"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)

            Menu {
                ForEach(VideoProcessingSettings.Codec.allCases) { codec in
                    Button {
                        model.settings.codec = codec
                    } label: {
                        Label(
                            codec.title(isArabic: preferences.isArabic),
                            systemImage: model.settings.codec == codec ? "checkmark" : ""
                        )
                    }
                }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.settings.codec.title(isArabic: preferences.isArabic))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)

                    Spacer()

                    Text(preferences.text(ar: "متقدم", en: "Advanced"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.30))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(VIPPlainButtonStyle())
        }
        .disabled(model.isProcessing)
        .sensoryFeedback(.selection, trigger: model.settings.codec.id) { oldValue, newValue in
            preferences.hapticsEnabled && oldValue != newValue
        }
    }

    private func controlHeading(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)

            Spacer()

            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var adjustmentDisclosure: some View {
        DisclosureGroup {
            adjustmentPanel
                .padding(.top, 18)
        } label: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(preferences.text(ar: "تحسين الصورة", en: "Enhancement"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    Text(model.enhancement.mode.title(isArabic: preferences.isArabic))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 7)
        }
        .tint(.secondary)
        .overlay(alignment: .top) { IrfaaliHairline() }
    }

    private var adjustmentPanel: some View {
        VStack(alignment: .leading, spacing: 22) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(VideoEnhancementSettings.Mode.allCases.filter { $0 != .custom }) { mode in
                        let selected = model.enhancement.mode == mode

                        Button {
                            model.applyEnhancementMode(mode)
                            showOriginal = false
                            previewExport = false
                        } label: {
                            VStack(spacing: 6) {
                                Text(mode.title(isArabic: preferences.isArabic))
                                    .font(.caption.weight(selected ? .semibold : .medium))
                                    .foregroundStyle(selected ? .white : .secondary)

                                Rectangle()
                                    .fill(selected ? IrfaaliVisual.electricCyan : Color.clear)
                                    .frame(height: 1)
                            }
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

            Text(preferences.text(ar: "خفيف أحسن. خل الصورة طبيعية.", en: "Keep it light for a natural result."))
                .font(.caption2)
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

        return VStack(spacing: 8) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: icon)
                        .font(.caption2.weight(.semibold))
                        .frame(width: 14)
                    Text(preferences.text(ar: ar, en: en))
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int((value * 100).rounded()))%")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.76))
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

    private func outputSummary(_ info: VideoAssetInfo) -> some View {
        let size = model.settings.targetSize(for: info)
        let fps = model.settings.frameRate.requestedFPS ?? info.sourceFPS
        let codec = model.settings.codec.title(isArabic: preferences.isArabic)

        return HStack(alignment: .lastTextBaseline, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(preferences.text(ar: "المخرج", en: "Target"))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)

                Text("\(Int(size.width))×\(Int(size.height))")
                    .font(.system(size: 25, weight: .semibold, design: .default))
                    .monospacedDigit()

                Text("\(IrfaaliFormatters.fps(fps)) · \(codec)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Rectangle()
                .fill(IrfaaliVisual.electricCyan)
                .frame(width: 18, height: 1)
                .padding(.bottom, 4)
        }
        .padding(.top, 4)
        .overlay(alignment: .top) { IrfaaliHairline() }
    }

    private func processCommitAction(_ info: VideoAssetInfo) -> some View {
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
            VStack(spacing: 0) {
                IrfaaliHairline()

                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preferences.text(ar: "معالجة الفيديو", en: "Process video"))
                            .font(.title3.weight(.semibold))

                        Text(processingSummary(info))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: preferences.isArabic ? "arrow.left" : "arrow.right")
                        .font(.headline.weight(.medium))
                        .foregroundStyle(IrfaaliVisual.electricCyan)
                }
                .frame(minHeight: 76)

                Rectangle()
                    .fill(IrfaaliVisual.electricCyan.opacity(0.72))
                    .frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PremiumProcessButtonStyle())
        .disabled(model.isAnalyzing || model.isProcessing)
    }

    private var processingProgress: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(preferences.text(ar: model.processingStageTextArabic, en: model.processingStageTextEnglish))
                        .font(.subheadline.weight(.semibold))
                    Text(processingStageCaption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(Int(model.progress * 100))%")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.76))
                    .contentTransition(.numericText())
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 0.5)
                    Rectangle()
                        .fill(IrfaaliVisual.electricCyan)
                        .frame(width: max(1, proxy.size.width * model.progress), height: 1)
                }
            }
            .frame(height: 1)

            if model.canCancelProcessing {
                Button {
                    model.cancelProcessing()
                } label: {
                    Text(preferences.text(ar: "إلغاء المعالجة", en: "Cancel processing"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(minHeight: 40)
                }
                .buttonStyle(VIPPlainButtonStyle())
            }
        }
    }

    // MARK: - Source details

    private func sourceDisclosure(_ info: VideoAssetInfo) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 20) {
                sourceCard(info)
                compactSourceReplacement
            }
            .padding(.top, 18)
        } label: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(preferences.text(ar: "معلومات المصدر", en: "Source information"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(info.fileName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.vertical, 7)
        }
        .tint(.secondary)
        .overlay(alignment: .top) { IrfaaliHairline() }
    }

    private func sourceCard(_ info: VideoAssetInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 24) {
                SourceMetric(
                    title: preferences.text(ar: "الدقة", en: "Resolution"),
                    value: "\(info.width)×\(info.height)"
                )

                SourceMetric(
                    title: preferences.text(ar: "الفريمات", en: "Frame rate"),
                    value: IrfaaliFormatters.fps(info.sourceFPS)
                )
            }

            DisclosureGroup(
                preferences.text(ar: "التفاصيل", en: "Details"),
                isExpanded: $showSourceDetails
            ) {
                VStack(spacing: 10) {
                    detailRow(title: preferences.text(ar: "الترميز", en: "Video Codec"), value: info.videoCodec)
                    detailRow(title: preferences.text(ar: "البت ريت", en: "Bitrate"), value: IrfaaliFormatters.bitrate(info.estimatedBitrate))
                    detailRow(title: preferences.text(ar: "المدة", en: "Duration"), value: IrfaaliFormatters.duration(info.duration))
                    detailRow(title: preferences.text(ar: "الصوت", en: "Audio"), value: audioSummary(info))
                    detailRow(title: preferences.text(ar: "الحاوية", en: "Container"), value: info.container)
                }
                .padding(.top, 12)
            }
            .font(.caption.weight(.medium))
            .tint(.secondary)
        }
    }

    private var compactSourceReplacement: some View {
        HStack(spacing: 18) {
            PhotosPicker(selection: $photoItem, matching: .videos) {
                Label(preferences.text(ar: "تغيير", en: "Change"), systemImage: "photo.on.rectangle")
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: 40)
            }
            .buttonStyle(VIPPlainButtonStyle())

            Button { showFileImporter = true } label: {
                Label(preferences.text(ar: "ملفات", en: "Files"), systemImage: "folder")
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: 40)
            }
            .buttonStyle(VIPPlainButtonStyle())

            Spacer()
        }
        .foregroundStyle(.secondary)
        .disabled(model.isAnalyzing || model.isProcessing)
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    // MARK: - State copy and outcome

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
            return preferences.text(ar: "استعادة التفاصيل", en: "Restoring detail")
        case .verifying:
            return preferences.text(ar: "التجهيز", en: "Finalizing")
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
            IrfaaliHairline()

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preferences.text(ar: "الفيديو جاهز", en: "Video ready"))
                        .font(.title3.weight(.semibold))
                    Text(fpsText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(IrfaaliVisual.electricCyan)
            }

            if let source = model.info, let output {
                HStack(spacing: 18) {
                    ComparisonColumn(
                        title: preferences.text(ar: "قبل", en: "Before"),
                        resolution: "\(source.width)×\(source.height)",
                        fps: IrfaaliFormatters.fps(source.sourceFPS),
                        codec: source.videoCodec
                    )

                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 0.5, height: 54)

                    ComparisonColumn(
                        title: preferences.text(ar: "بعد", en: "After"),
                        resolution: "\(output.width)×\(output.height)",
                        fps: IrfaaliFormatters.fps(output.sourceFPS),
                        codec: output.videoCodec
                    )
                }
            }

            HStack(spacing: 12) {
                Button {
                    Task { await model.saveOutputToPhotos() }
                } label: {
                    saveButtonLabel
                }
                .buttonStyle(PremiumPrimaryButtonStyle())
                .disabled(model.saveState == .saving || model.saveState == .saved)

                ShareLink(item: outcome.url) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PremiumSecondaryButtonStyle())
            }

            if case .failed(let message) = model.saveState {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var saveButtonLabel: some View {
        switch model.saveState {
        case .idle:
            Label(preferences.text(ar: "حفظ في الصور", en: "Save to Photos"), systemImage: "square.and.arrow.down")
                .frame(maxWidth: .infinity)
        case .saving:
            Text(preferences.text(ar: "جارٍ الحفظ…", en: "Saving…"))
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
                .frame(width: 20)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { IrfaaliHairline() }
    }
}

private struct ImportGateMarks: View {
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    corner(horizontal: .leading, vertical: .top)
                    Spacer()
                    corner(horizontal: .trailing, vertical: .top)
                }
                Spacer()
                HStack {
                    corner(horizontal: .leading, vertical: .bottom)
                    Spacer()
                    corner(horizontal: .trailing, vertical: .bottom)
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.055))
                .frame(height: 0.5)
                .padding(.horizontal, 28)
        }
        .padding(2)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func corner(horizontal: HorizontalAlignment, vertical: VerticalAlignment) -> some View {
        ZStack(alignment: Alignment(horizontal: horizontal, vertical: vertical)) {
            Rectangle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 30, height: 0.5)
            Rectangle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 0.5, height: 22)
        }
        .frame(width: 30, height: 22, alignment: Alignment(horizontal: horizontal, vertical: vertical))
    }
}

private struct SourceMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
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
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)

            Text(resolution)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)

            Text("\(fps) · \(codec)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            let handleWidth: CGFloat = 2
            let usableWidth = max(1, proxy.size.width - handleWidth)
            let displayProgress = layoutDirection == .rightToLeft ? 1 - normalized : normalized
            let handleX = CGFloat(displayProgress) * usableWidth

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(isDragging ? 0.18 : 0.10))
                    .frame(height: 0.5)

                HStack {
                    ForEach(0..<9, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(isDragging ? 0.22 : 0.10))
                            .frame(width: 0.5, height: 5)
                        if _ != 8 { Spacer() }
                    }
                }

                Rectangle()
                    .fill(isDragging ? IrfaaliVisual.electricCyan : Color.white.opacity(0.76))
                    .frame(width: handleWidth, height: isDragging ? 20 : 14)
                    .offset(x: handleX)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let raw = Double((gesture.location.x - handleWidth / 2) / usableWidth)
                        let display = min(max(raw, 0), 1)
                        let logical = layoutDirection == .rightToLeft ? 1 - display : display
                        value = range.lowerBound + logical * (range.upperBound - range.lowerBound)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: 28)
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
            .opacity(configuration.isPressed ? 0.76 : 1)
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

private struct PremiumPrimaryButtonStyle: ButtonStyle {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(Color.white.opacity(configuration.isPressed ? 0.13 : 0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
            .opacity(configuration.isPressed ? 0.82 : 1)
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
            .padding(.horizontal, 11)
            .frame(minHeight: 44)
            .background(Color.white.opacity(configuration.isPressed ? 0.08 : 0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
