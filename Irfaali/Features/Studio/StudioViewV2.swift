import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct StudioViewV2: View {
    @StateObject private var model = StudioViewModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var showOriginal = false
    @State private var previewExport = false
    @State private var restorationExpanded = false
    @State private var advancedExpanded = false
    @State private var sourceExpanded = false
    @State private var hasAppeared = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        ZStack {
            ThemeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if model.info == nil {
                        openingHeader
                        importPortal
                    }

                    if let info = model.info {
                        mediaStage(info)
                        analysisSection(info)

                        if let recommendation = model.recommendation, !model.isAnalyzing {
                            recommendationSection(recommendation)
                        }

                        outputSection(info)
                        restorationSection(info)
                        advancedSection(info)
                        processSection(info)

                        if let outcome = model.lastOutcome {
                            resultSection(outcome, source: info)
                        }
                    } else if model.isAnalyzing {
                        analysisLoadingSection
                    }

                    if let validationMessage = model.validationMessage {
                        messageStrip(
                            validationMessage,
                            icon: "exclamationmark.triangle.fill",
                            tint: .orange
                        )
                    }

                    if let errorMessage = model.errorMessage {
                        messageStrip(
                            errorMessage,
                            icon: "exclamationmark.octagon.fill",
                            tint: .red
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, model.info == nil ? 24 : 10)
                .padding(.bottom, 54)
                .opacity(hasAppeared ? 1 : 0)
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
                        .frame(height: 27)
                        .accessibilityLabel(AppBranding.appName)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(selection: $photoItem, matching: .videos) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(V2PressStyle())
                    .disabled(model.isAnalyzing || model.isProcessing)
                    .accessibilityLabel(preferences.text(ar: "تغيير الفيديو", en: "Change video"))
                }
            }
        }
        .animation(
            preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.15) : nil,
            value: model.info?.url
        )
        .animation(
            preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.15) : nil,
            value: model.isAnalyzing
        )
        .animation(
            preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.15) : nil,
            value: model.isProcessing
        )
        .onAppear {
            guard !hasAppeared else { return }
            if preferences.animationsEnabled && !reduceMotion {
                withAnimation(.easeOut(duration: 0.18)) {
                    hasAppeared = true
                }
            } else {
                hasAppeared = true
            }
        }
        .onChange(of: preferences.language, initial: true) { _, _ in
            model.isArabic = preferences.isArabic
        }
        .onChange(of: model.info?.url) { _, _ in
            showOriginal = false
            previewExport = false
            restorationExpanded = false
            advancedExpanded = false
            sourceExpanded = false
        }
        .onChange(of: model.lastOutcome?.url) { _, output in
            if output != nil { previewExport = true }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await importPhotoItem(item) }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.movie]) { result in
            switch result {
            case .success(let url):
                Task { await importFileURL(url) }
            case .failure(let error):
                model.errorMessage = AppErrorMessage.describe(error, isArabic: preferences.isArabic)
            }
        }
    }

    // MARK: - Opening

    private var openingHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image("OfficialLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 66, height: 66)
                .padding(.bottom, 25)

            Text(AppBranding.appName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            Text(preferences.text(ar: "الفيديو أولاً.\nثم القرار.", en: "Start with the footage.\nThen decide."))
                .font(.system(size: 36, weight: .bold))
                .tracking(preferences.isArabic ? 0 : -1.1)
                .lineSpacing(preferences.isArabic ? 3 : 0)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)

            Text(
                preferences.text(
                    ar: "ارفعلي يقرأ اللقطة قبل أن يقترح أي تغيير.",
                    en: "Irfaali reads the footage before suggesting any change."
                )
            )
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var importPortal: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $photoItem, matching: .videos) {
                VStack(spacing: 14) {
                    Image(systemName: "plus")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(IrfaaliVisual.electricCyan)

                    VStack(spacing: 4) {
                        Text(preferences.text(ar: "اختر فيديو", en: "Choose a video"))
                            .font(.headline.weight(.semibold))

                        Text(preferences.text(ar: "من مكتبة الصور", en: "From your photo library"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 136)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 0.7)
                }
                .background(
                    Color.white.opacity(0.022),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            .buttonStyle(V2PressStyle())

            Button { showFileImporter = true } label: {
                Label(preferences.text(ar: "اختيار من الملفات", en: "Choose from Files"), systemImage: "folder")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(V2PressStyle())
        }
        .disabled(model.isAnalyzing || model.isProcessing)
    }

    // MARK: - Media

    private func mediaStage(_ info: VideoAssetInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if model.isProcessing {
                    ZStack {
                        VideoThumbnailView(url: info.url, isAvailable: true)
                        Color.black.opacity(0.26)

                        VStack(spacing: 12) {
                            Text(preferences.text(ar: model.processingStageTextArabic, en: model.processingStageTextEnglish))
                                .font(.subheadline.weight(.semibold))

                            ProgressView(value: model.progress)
                                .tint(IrfaaliVisual.electricCyan)
                                .frame(width: 160)

                            Text("\(Int((model.progress * 100).rounded()))%")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(18)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
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

            if !model.isProcessing {
                HStack(spacing: 22) {
                    modeButton(
                        title: preferences.text(ar: "الأصل", en: "Original"),
                        selected: !previewExport && showOriginal
                    ) {
                        previewExport = false
                        showOriginal = true
                    }

                    modeButton(
                        title: preferences.text(ar: "المعاينة", en: "Preview"),
                        selected: !previewExport && !showOriginal
                    ) {
                        previewExport = false
                        showOriginal = false
                    }

                    if model.lastOutcome != nil {
                        modeButton(
                            title: preferences.text(ar: "الناتج", en: "Export"),
                            selected: previewExport
                        ) {
                            previewExport = true
                            showOriginal = false
                        }
                    }

                    Spacer()
                }
            }
        }
    }

    private func mediaMetadata(_ info: VideoAssetInfo) -> some View {
        LinearGradient(
            colors: [.clear, Color.black.opacity(0.78)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 88)
        .overlay(alignment: .bottomLeading) {
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(info.fileName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    Text("\(info.width)×\(info.height) · \(IrfaaliFormatters.fps(info.sourceFPS))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.64))
                }

                Spacer()

                Text(
                    preferences.text(
                        ar: previewExport ? "الناتج" : (showOriginal ? "الأصل" : "المعاينة"),
                        en: previewExport ? "EXPORT" : (showOriginal ? "ORIGINAL" : "PREVIEW")
                    )
                )
                .font(.caption2.weight(.semibold))
                .tracking(preferences.isArabic ? 0 : 0.75)
                .foregroundStyle(.white.opacity(0.70))
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .allowsHitTesting(false)
    }

    private func modeButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(title)
                    .font(.caption.weight(selected ? .semibold : .medium))
                    .foregroundStyle(selected ? .white : .secondary)

                Rectangle()
                    .fill(selected ? IrfaaliVisual.electricCyan : Color.clear)
                    .frame(height: 1)
            }
        }
        .buttonStyle(V2PressStyle())
    }

    // MARK: - Analysis

    private var analysisLoadingSection: some View {
        sectionShell(title: preferences.text(ar: "تحليل الفيديو", en: "Video analysis")) {
            HStack(spacing: 12) {
                IrfaaliMiniActivity()

                VStack(alignment: .leading, spacing: 3) {
                    Text(preferences.text(ar: model.analysisStageTextArabic, en: model.analysisStageTextEnglish))
                        .font(.subheadline.weight(.semibold))

                    Text(
                        preferences.text(
                            ar: "نقرأ خصائص الفيديو ثم نفحص عينات من اللقطات.",
                            en: "Reading the file, then inspecting sampled frames."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func analysisSection(_ info: VideoAssetInfo) -> some View {
        sectionShell(title: preferences.text(ar: "تحليل الفيديو", en: "Video analysis")) {
            if model.isAnalyzing {
                HStack(spacing: 12) {
                    IrfaaliMiniActivity()

                    VStack(alignment: .leading, spacing: 3) {
                        Text(preferences.text(ar: model.analysisStageTextArabic, en: model.analysisStageTextEnglish))
                            .font(.subheadline.weight(.semibold))
                        Text(preferences.text(ar: "نحلل الصورة والحركة بدون تغيير الفيديو.", en: "Analyzing image and motion without changing the video."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let report = model.analysisReport {
                if report.sampledFrameCount == 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(preferences.text(ar: "تحليل محافظ", en: "Conservative analysis"))
                            .font(.subheadline.weight(.semibold))
                        Text(
                            preferences.text(
                                ar: "تعذر فحص الصورة فريمًا بفريم، لذلك لم نفترض وجود عيوب غير مؤكدة.",
                                en: "Frame sampling was unavailable, so Irfaali did not assume defects that were not measured."
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 0) {
                        analysisRow(
                            title: preferences.text(ar: "الإضاءة", en: "Exposure"),
                            value: exposureLabel(report),
                            score: report.averageLuminance
                        )
                        IrfaaliHairline()
                        analysisRow(
                            title: preferences.text(ar: "التفاصيل", en: "Detail"),
                            value: sharpnessLabel(report),
                            score: report.sharpnessScore
                        )
                        IrfaaliHairline()
                        analysisRow(
                            title: preferences.text(ar: "التشويش", en: "Noise"),
                            value: severityLabel(report.noiseScore),
                            score: report.noiseScore
                        )
                        IrfaaliHairline()
                        analysisRow(
                            title: preferences.text(ar: "آثار الضغط", en: "Compression"),
                            value: severityLabel(report.compressionArtifactScore),
                            score: report.compressionArtifactScore
                        )
                        IrfaaliHairline()
                        analysisRow(
                            title: preferences.text(ar: "الحركة", en: "Motion"),
                            value: motionLabel(report.motionLevel),
                            score: report.motionScore
                        )
                    }

                    Text(
                        preferences.text(
                            ar: "تم فحص \(report.sampledFrameCount) لقطات موزعة على مدة الفيديو.",
                            en: "Measured \(report.sampledFrameCount) frames distributed across the video."
                        )
                    )
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 12)
                }
            } else {
                Text(preferences.text(ar: "لا توجد نتيجة تحليل بعد.", en: "No analysis result yet."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func analysisRow(title: String, value: String, score: Double) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
            }

            Spacer()

            Text("\(Int((min(max(score, 0), 1) * 100).rounded()))")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(minHeight: 54)
    }

    // MARK: - Recommendation

    private func recommendationSection(_ recommendation: VideoRecommendation) -> some View {
        sectionShell(title: preferences.text(ar: "التوصية", en: "Recommendation")) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(recommendation.title(isArabic: preferences.isArabic))
                            .font(.title3.weight(.semibold))

                        Text(recommendation.explanation(isArabic: preferences.isArabic))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Rectangle()
                        .fill(IrfaaliVisual.electricCyan)
                        .frame(width: 18, height: 1)
                        .padding(.top, 11)
                }

                recommendationSummary(recommendation)

                Button {
                    model.applyRecommendedSettings()
                    showOriginal = false
                    previewExport = false
                } label: {
                    HStack {
                        Text(
                            recommendationApplied
                                ? preferences.text(ar: "تم تطبيق التوصية", en: "Recommendation applied")
                                : preferences.text(ar: "تطبيق التوصية", en: "Apply recommendation")
                        )
                        .font(.subheadline.weight(.semibold))

                        Spacer()

                        Image(systemName: recommendationApplied ? "checkmark" : (preferences.isArabic ? "arrow.left" : "arrow.right"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(IrfaaliVisual.electricCyan)
                    }
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(V2PressStyle())
                .disabled(recommendationApplied || model.isProcessing)
                .overlay(alignment: .top) { IrfaaliHairline() }
            }
        }
    }

    private func recommendationSummary(_ recommendation: VideoRecommendation) -> some View {
        let resolution = recommendation.processing.resolution.title(isArabic: preferences.isArabic)
        let fps = recommendation.processing.frameRate.title(isArabic: preferences.isArabic)
        let restoration = recommendation.enhancement.mode.title(isArabic: preferences.isArabic)

        return HStack(spacing: 0) {
            compactMetric(preferences.text(ar: "الجودة", en: "Quality"), resolution)
            compactMetric(preferences.text(ar: "الحركة", en: "Motion"), fps)
            compactMetric(preferences.text(ar: "الترميم", en: "Restoration"), restoration)
        }
        .padding(.vertical, 4)
    }

    private func compactMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recommendationApplied: Bool {
        guard let recommendation = model.recommendation else { return false }
        return model.settings == recommendation.processing && model.enhancement == recommendation.enhancement
    }

    // MARK: - Output

    private func outputSection(_ info: VideoAssetInfo) -> some View {
        sectionShell(title: preferences.text(ar: "النتيجة", en: "Output")) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    controlHeading(
                        preferences.text(ar: "الجودة", en: "Quality"),
                        value: model.settings.resolution.title(isArabic: preferences.isArabic)
                    )

                    HStack(spacing: 8) {
                        ForEach(VideoProcessingSettings.supportedResolutions(for: info)) { resolution in
                            optionButton(
                                title: resolution.title(isArabic: preferences.isArabic),
                                selected: model.settings.resolution == resolution
                            ) {
                                model.settings.resolution = resolution
                                previewExport = false
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    controlHeading(
                        preferences.text(ar: "معدل الإطارات", en: "Frame rate"),
                        value: model.settings.frameRate.title(isArabic: preferences.isArabic)
                    )

                    HStack(spacing: 8) {
                        ForEach(VideoProcessingSettings.supportedFrameRates(for: info)) { frameRate in
                            optionButton(
                                title: frameRate.title(isArabic: preferences.isArabic),
                                selected: model.settings.frameRate == frameRate
                            ) {
                                model.settings.frameRate = frameRate
                                previewExport = false
                            }
                        }
                    }
                }

                targetSummary(info)

                if let note = outputNote(info) {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .disabled(model.isProcessing)
    }

    private func optionButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.caption.monospacedDigit().weight(selected ? .bold : .medium))
                    .foregroundStyle(selected ? .white : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)

                Rectangle()
                    .fill(selected ? IrfaaliVisual.electricCyan : Color.white.opacity(0.10))
                    .frame(height: selected ? 1 : 0.5)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(V2PressStyle())
    }

    private func targetSummary(_ info: VideoAssetInfo) -> some View {
        let size = model.settings.targetSize(for: info)
        let fps = model.settings.frameRate.requestedFPS ?? info.sourceFPS

        return HStack(alignment: .lastTextBaseline, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(preferences.text(ar: "المخرج", en: "Target"))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)

                Text("\(Int(size.width))×\(Int(size.height))")
                    .font(.system(size: 24, weight: .semibold))
                    .monospacedDigit()

                Text("\(IrfaaliFormatters.fps(fps)) · \(model.settings.codec.title(isArabic: preferences.isArabic))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Rectangle()
                .fill(IrfaaliVisual.electricCyan)
                .frame(width: 18, height: 1)
                .padding(.bottom, 4)
        }
        .padding(.top, 2)
        .overlay(alignment: .top) { IrfaaliHairline() }
    }

    // MARK: - Restoration

    private func restorationSection(_ info: VideoAssetInfo) -> some View {
        sectionShell(title: preferences.text(ar: "الترميم", en: "Restoration")) {
            DisclosureGroup(isExpanded: $restorationExpanded) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 8) {
                        ForEach(VideoEnhancementSettings.Mode.allCases.filter { $0 != .custom }) { mode in
                            optionButton(
                                title: mode.title(isArabic: preferences.isArabic),
                                selected: model.enhancement.mode == mode
                            ) {
                                model.applyEnhancementMode(mode)
                                showOriginal = false
                                previewExport = false
                            }
                        }
                    }

                    if model.enhancement.mode != .off {
                        restorationSlider(
                            title: preferences.text(ar: "تنظيف التشويش", en: "Noise cleanup"),
                            keyPath: \VideoEnhancementSettings.denoise
                        )
                        restorationSlider(
                            title: preferences.text(ar: "استعادة التفاصيل", en: "Detail recovery"),
                            keyPath: \VideoEnhancementSettings.detailRecovery
                        )
                        restorationSlider(
                            title: preferences.text(ar: "الحدة", en: "Sharpening"),
                            keyPath: \VideoEnhancementSettings.sharpening
                        )
                        restorationSlider(
                            title: preferences.text(ar: "حيوية اللون", en: "Color"),
                            keyPath: \VideoEnhancementSettings.colorBoost
                        )

                        DisclosureGroup(preferences.text(ar: "الضوء والتباين", en: "Light & contrast")) {
                            VStack(spacing: 18) {
                                restorationSlider(
                                    title: preferences.text(ar: "الإضاءة", en: "Exposure"),
                                    keyPath: \VideoEnhancementSettings.exposure,
                                    range: -1...1
                                )
                                restorationSlider(
                                    title: preferences.text(ar: "التباين", en: "Contrast"),
                                    keyPath: \VideoEnhancementSettings.contrast,
                                    range: -1...1
                                )
                            }
                            .padding(.top, 14)
                        }
                        .font(.caption.weight(.medium))
                        .tint(.secondary)
                    }

                    Text(
                        preferences.text(
                            ar: "المعالجة الخفيفة أفضل من المبالغة. الهدف هو إصلاح العيب بدون تغيير طبيعة اللقطة.",
                            en: "Light treatment is better than over-processing. The goal is to repair defects without changing the character of the footage."
                        )
                    )
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 16)
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(preferences.text(ar: "تحسين الصورة", en: "Image treatment"))
                            .font(.subheadline.weight(.medium))
                        Text(model.enhancement.mode.title(isArabic: preferences.isArabic))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 5)
            }
            .tint(.secondary)
        }
        .disabled(model.isProcessing)
    }

    private func restorationSlider(
        title: String,
        keyPath: WritableKeyPath<VideoEnhancementSettings, Double>,
        range: ClosedRange<Double> = 0...1
    ) -> some View {
        let value = model.enhancement[keyPath: keyPath]
        let displayValue = Int((value * 100).rounded())

        return VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(displayValue)%")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.76))
            }

            Slider(
                value: Binding(
                    get: { model.enhancement[keyPath: keyPath] },
                    set: { newValue in
                        model.updateEnhancement(keyPath, value: newValue)
                        showOriginal = false
                        previewExport = false
                    }
                ),
                in: range
            )
            .tint(IrfaaliVisual.electricCyan)
        }
    }

    // MARK: - Advanced

    private func advancedSection(_ info: VideoAssetInfo) -> some View {
        sectionShell(title: preferences.text(ar: "المتقدم", en: "Advanced")) {
            DisclosureGroup(isExpanded: $advancedExpanded) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(preferences.text(ar: "الترميز", en: "Encoding"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.tertiary)

                        Menu {
                            ForEach(VideoProcessingSettings.Codec.allCases) { codec in
                                Button(codec.title(isArabic: preferences.isArabic)) {
                                    model.settings.codec = codec
                                }
                            }
                        } label: {
                            HStack {
                                Text(model.settings.codec.title(isArabic: preferences.isArabic))
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(V2PressStyle())
                    }

                    DisclosureGroup(isExpanded: $sourceExpanded) {
                        VStack(spacing: 10) {
                            detailRow(preferences.text(ar: "الدقة", en: "Resolution"), "\(info.width)×\(info.height)")
                            detailRow(preferences.text(ar: "الفريمات", en: "Frame rate"), IrfaaliFormatters.fps(info.sourceFPS))
                            detailRow(preferences.text(ar: "الترميز", en: "Codec"), info.videoCodec)
                            detailRow(preferences.text(ar: "البت ريت", en: "Bitrate"), IrfaaliFormatters.bitrate(info.estimatedBitrate))
                            detailRow(preferences.text(ar: "المدى", en: "Range"), info.dynamicRange)
                            detailRow(preferences.text(ar: "الصوت", en: "Audio"), audioSummary(info))
                            detailRow(preferences.text(ar: "المدة", en: "Duration"), IrfaaliFormatters.duration(info.duration))
                        }
                        .padding(.top, 12)
                    } label: {
                        Text(preferences.text(ar: "معلومات المصدر", en: "Source information"))
                            .font(.caption.weight(.medium))
                    }
                    .tint(.secondary)
                }
                .padding(.top, 16)
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(preferences.text(ar: "خيارات تقنية", en: "Technical options"))
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(model.settings.codec.title(isArabic: preferences.isArabic))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 5)
            }
            .tint(.secondary)
        }
        .disabled(model.isProcessing)
    }

    // MARK: - Process

    private func processSection(_ info: VideoAssetInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.isProcessing {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preferences.text(ar: model.processingStageTextArabic, en: model.processingStageTextEnglish))
                            .font(.subheadline.weight(.semibold))
                        Text(processingSummary(info))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(Int((model.progress * 100).rounded()))%")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                }

                ProgressView(value: model.progress)
                    .tint(IrfaaliVisual.electricCyan)

                if model.canCancelProcessing {
                    Button {
                        model.cancelProcessing()
                    } label: {
                        Text(preferences.text(ar: "إلغاء المعالجة", en: "Cancel processing"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(minHeight: 40)
                    }
                    .buttonStyle(V2PressStyle())
                }
            } else {
                Button {
                    Task { await processAndStore(info) }
                } label: {
                    VStack(spacing: 0) {
                        IrfaaliHairline()

                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preferences.text(ar: "معالجة الفيديو", en: "Process video"))
                                    .font(.title3.weight(.semibold))

                                Text(processingSummary(info))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.68)
                            }

                            Spacer(minLength: 10)

                            Image(systemName: preferences.isArabic ? "arrow.left" : "arrow.right")
                                .font(.headline.weight(.medium))
                                .foregroundStyle(IrfaaliVisual.electricCyan)
                        }
                        .frame(minHeight: 78)

                        Rectangle()
                            .fill(IrfaaliVisual.electricCyan.opacity(model.canProcess ? 0.72 : 0.20))
                            .frame(height: 1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(V2PressStyle())
                .disabled(!model.canProcess)

                if model.needsFrameGeneration, model.frameGenerationReadiness?.canStart == false {
                    Text(
                        preferences.text(
                            ar: "معالجة معدل الإطارات غير متاحة الآن بحالة الجهاز أو حجم الفيديو الحالي.",
                            en: "Frame-rate processing is unavailable with the current device state or video size."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }
        }
    }

    private func processAndStore(_ info: VideoAssetInfo) async {
        guard let result = await model.process() else { return }

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

    // MARK: - Result

    private func resultSection(_ outcome: ExportOutcome, source: VideoAssetInfo) -> some View {
        sectionShell(title: preferences.text(ar: "الناتج", en: "Result")) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preferences.text(ar: "الفيديو جاهز", en: "Video ready"))
                            .font(.title3.weight(.semibold))

                        if let output = model.outputInfo {
                            Text("\(output.width)×\(output.height) · \(IrfaaliFormatters.fps(output.sourceFPS)) · \(output.videoCodec)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(IrfaaliVisual.electricCyan)
                }

                if let output = model.outputInfo {
                    HStack(spacing: 18) {
                        comparisonColumn(
                            title: preferences.text(ar: "قبل", en: "Before"),
                            resolution: "\(source.width)×\(source.height)",
                            fps: IrfaaliFormatters.fps(source.sourceFPS),
                            codec: source.videoCodec
                        )

                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 0.5, height: 56)

                        comparisonColumn(
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
                    .buttonStyle(V2FilledButtonStyle())
                    .disabled(model.saveState == .saving || model.saveState == .saved)

                    ShareLink(item: outcome.url) {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: 46, height: 46)
                    }
                    .buttonStyle(V2SecondaryButtonStyle())
                }

                if case .failed(let message) = model.saveState {
                    Text(message)
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

    private func comparisonColumn(title: String, resolution: String, fps: String, codec: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
            Text(resolution)
                .font(.subheadline.monospacedDigit().weight(.semibold))
            Text("\(fps) · \(codec)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Shared view helpers

    private func sectionShell<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased(with: preferences.locale))
                    .font(.caption2.weight(.semibold))
                    .tracking(preferences.isArabic ? 0.15 : 1.05)
                    .foregroundStyle(.tertiary)
                Spacer()
            }

            content()
        }
        .padding(.top, 2)
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
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 10)
            Text(value)
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(.white.opacity(0.84))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private func messageStrip(_ message: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 20)

            Text(message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) { IrfaaliHairline() }
    }

    private func outputNote(_ info: VideoAssetInfo) -> String? {
        let target = model.settings.targetSize(for: info)
        let upscales = max(target.width, target.height) > CGFloat(max(info.width, info.height))
        var notes: [String] = []

        if upscales {
            notes.append(
                preferences.text(
                    ar: "رفع الدقة يغيّر حجم الإخراج، لكنه لا يخلق تفاصيل غير موجودة في المصدر من تلقاء نفسه.",
                    en: "A larger output changes resolution, but it does not automatically recreate detail that is absent from the source."
                )
            )
        }

        if model.needsFrameGeneration {
            notes.append(
                preferences.text(
                    ar: "رفع معدل الإطارات يعتمد على تقدير الحركة ويحتاج وقتًا ومعالجة إضافية.",
                    en: "Higher frame rates require motion estimation and additional processing time."
                )
            )
        }

        return notes.isEmpty ? nil : notes.joined(separator: "\n")
    }

    private func processingSummary(_ info: VideoAssetInfo) -> String {
        let size = model.settings.targetSize(for: info)
        let fps = model.settings.frameRate.requestedFPS ?? info.sourceFPS
        let base = "\(Int(size.width))×\(Int(size.height)) · \(IrfaaliFormatters.fps(fps)) · \(model.settings.codec.title(isArabic: preferences.isArabic))"
        guard model.enhancement.isEnabled else { return base }
        return "\(base) · \(model.enhancement.mode.title(isArabic: preferences.isArabic))"
    }

    private func audioSummary(_ info: VideoAssetInfo) -> String {
        guard let codec = info.audioCodec else {
            return preferences.text(ar: "بدون صوت", en: "No audio")
        }

        let channels = info.audioChannels.map { "\($0)ch" } ?? ""
        let sampleRate = info.audioSampleRate.map { String(format: "%.1fkHz", $0 / 1000) } ?? ""
        return [codec, channels, sampleRate].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func exposureLabel(_ report: VideoAnalysisReport) -> String {
        if report.isHighlightLimited {
            return preferences.text(ar: "إضاءات قوية", en: "Highlight limited")
        }
        if report.isLowLight {
            return preferences.text(ar: "منخفضة", en: "Low")
        }
        return preferences.text(ar: "متوازنة", en: "Balanced")
    }

    private func sharpnessLabel(_ report: VideoAnalysisReport) -> String {
        report.isSoft
            ? preferences.text(ar: "ناعمة", en: "Soft")
            : preferences.text(ar: "جيدة", en: "Good")
    }

    private func severityLabel(_ score: Double) -> String {
        switch score {
        case ..<0.14:
            return preferences.text(ar: "خفيف", en: "Low")
        case ..<0.30:
            return preferences.text(ar: "متوسط", en: "Moderate")
        default:
            return preferences.text(ar: "مرتفع", en: "High")
        }
    }

    private func motionLabel(_ level: VideoAnalysisReport.MotionLevel) -> String {
        switch level {
        case .low:
            return preferences.text(ar: "هادئة", en: "Low")
        case .medium:
            return preferences.text(ar: "متوسطة", en: "Moderate")
        case .high:
            return preferences.text(ar: "سريعة", en: "Fast")
        }
    }

    // MARK: - Import helpers

    private func importPhotoItem(_ item: PhotosPickerItem) async {
        do {
            guard let movie = try await item.loadTransferable(type: VideoFileTransferable.self) else { return }
            await model.importVideo(url: movie.url)
        } catch {
            model.errorMessage = AppErrorMessage.describe(error, isArabic: preferences.isArabic)
        }
    }

    private func importFileURL(_ url: URL) async {
        let access = url.startAccessingSecurityScopedResource()
        defer {
            if access { url.stopAccessingSecurityScopedResource() }
        }

        let fileExtension = url.pathExtension.isEmpty ? "mov" : url.pathExtension
        let localURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("irfaali-v2-\(UUID().uuidString).\(fileExtension)")

        do {
            try FileManager.default.copyItem(at: url, to: localURL)
            await model.importVideo(url: localURL)
        } catch {
            model.errorMessage = AppErrorMessage.describe(error, isArabic: preferences.isArabic)
        }
    }
}

private struct V2PressStyle: ButtonStyle {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.80 : 1)
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

private struct V2FilledButtonStyle: ButtonStyle {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(
                Color.white.opacity(configuration.isPressed ? 0.14 : 0.085),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .scaleEffect(configuration.isPressed && preferences.animationsEnabled && !reduceMotion ? 0.98 : 1)
            .animation(
                preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.10) : nil,
                value: configuration.isPressed
            )
    }
}

private struct V2SecondaryButtonStyle: ButtonStyle {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .background(
                Color.white.opacity(configuration.isPressed ? 0.08 : 0.035),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .scaleEffect(configuration.isPressed && preferences.animationsEnabled && !reduceMotion ? 0.98 : 1)
            .animation(
                preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.10) : nil,
                value: configuration.isPressed
            )
    }
}
