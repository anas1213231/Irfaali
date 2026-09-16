import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct StudioViewV3: View {
    @StateObject private var model = StudioViewModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var previewMode: PreviewMode = .preview
    @State private var restorationExpanded = false
    @State private var advancedExpanded = false
    @State private var sourceExpanded = false
    @State private var hasAppeared = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: AppPreferences

    private enum PreviewMode: Hashable {
        case original
        case preview
        case export
    }

    var body: some View {
        ZStack {
            ThemeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if model.info == nil {
                        welcomeHeader
                        importPanel
                    }

                    if let info = model.info {
                        mediaStage(info)
                        analysisSection

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
                        messageStrip(validationMessage, icon: "exclamationmark.triangle.fill", tint: .orange)
                    }

                    if let errorMessage = model.errorMessage {
                        messageStrip(errorMessage, icon: "exclamationmark.octagon.fill", tint: .red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, model.info == nil ? 22 : 10)
                .padding(.bottom, 54)
                .opacity(hasAppeared ? 1 : 0)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.primary)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.info != nil {
                ToolbarItem(placement: .principal) {
                    Image("OfficialLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 25)
                        .accessibilityLabel(AppBranding.appName)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(selection: $photoItem, matching: .videos) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(IrfaaliTypography.control)
                    }
                    .buttonStyle(V3PressStyle())
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
            previewMode = .preview
            restorationExpanded = false
            advancedExpanded = false
            sourceExpanded = false
        }
        .onChange(of: model.lastOutcome?.url) { _, value in
            if value != nil { previewMode = .export }
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

    // MARK: - Welcome

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image("OfficialLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .padding(.bottom, 24)

            Text(AppBranding.appName)
                .font(IrfaaliTypography.metadata)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            Text(preferences.text(ar: "استعد الفيديو.\nبدون مبالغة.", en: "Restore the footage.\nKeep it natural."))
                .font(IrfaaliTypography.brandDisplay)
                .tracking(preferences.isArabic ? 0 : -0.8)
                .lineSpacing(preferences.isArabic ? 3 : 0)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)

            Text(
                preferences.text(
                    ar: "ابدأ بالفيديو، ثم اترك التحليل يحدد ما يحتاجه فعلاً قبل أي معالجة.",
                    en: "Start with the source, then let the analysis identify what actually needs attention before processing."
                )
            )
            .font(IrfaaliTypography.secondaryBody)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var importPanel: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $photoItem, matching: .videos) {
                VStack(spacing: 13) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(IrfaaliVisual.electricCyan)

                    VStack(spacing: 4) {
                        Text(preferences.text(ar: "اختر فيديو", en: "Choose a video"))
                            .font(IrfaaliTypography.button)

                        Text(preferences.text(ar: "من مكتبة الصور", en: "From your photo library"))
                            .font(IrfaaliTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 136)
                .background(surfaceFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(surfaceStroke, lineWidth: 0.6)
                }
            }
            .buttonStyle(V3PressStyle())

            Button { showFileImporter = true } label: {
                Label(preferences.text(ar: "اختيار من الملفات", en: "Choose from Files"), systemImage: "folder")
                    .font(IrfaaliTypography.captionStrong)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(V3PressStyle())
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
                        Color.black.opacity(0.34)

                        VStack(spacing: 12) {
                            Text(preferences.text(ar: model.processingStageTextArabic, en: model.processingStageTextEnglish))
                                .font(IrfaaliTypography.button)
                                .foregroundStyle(.white)

                            ProgressView(value: model.progress)
                                .tint(IrfaaliVisual.electricCyan)
                                .frame(width: 160)

                            Text("\(Int((model.progress * 100).rounded()))%")
                                .font(IrfaaliTypography.metadataMonospaced)
                                .foregroundStyle(.white.opacity(0.72))
                        }
                        .padding(18)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                } else {
                    VideoCanvas(
                        url: previewURL(info),
                        enhancement: previewMode == .preview ? model.enhancement : .off
                    )
                }
            }
            .frame(height: info.height > info.width ? 410 : 252)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                if !model.isProcessing { mediaMetadata(info) }
            }

            if !model.isProcessing {
                HStack(spacing: 22) {
                    previewModeButton(.original, title: preferences.text(ar: "الأصل", en: "Original"))
                    previewModeButton(.preview, title: preferences.text(ar: "المعاينة", en: "Preview"))
                    if model.lastOutcome != nil {
                        previewModeButton(.export, title: preferences.text(ar: "الناتج", en: "Export"))
                    }
                    Spacer()
                }
            }
        }
    }

    private func previewURL(_ info: VideoAssetInfo) -> URL {
        if previewMode == .export, let output = model.lastOutcome?.url { return output }
        return info.url
    }

    private func mediaMetadata(_ info: VideoAssetInfo) -> some View {
        LinearGradient(colors: [.clear, Color.black.opacity(0.80)], startPoint: .top, endPoint: .bottom)
            .frame(height: 92)
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .lastTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(info.fileName)
                            .font(IrfaaliTypography.captionStrong)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text("\(info.width)×\(info.height) · \(IrfaaliFormatters.fps(info.sourceFPS))")
                            .font(IrfaaliTypography.metadataMonospaced)
                            .foregroundStyle(.white.opacity(0.66))
                    }

                    Spacer()

                    Text(previewModeLabel)
                        .font(IrfaaliTypography.captionStrong)
                        .tracking(preferences.isArabic ? 0 : 0.7)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
            .allowsHitTesting(false)
    }

    private var previewModeLabel: String {
        switch previewMode {
        case .original: return preferences.text(ar: "الأصل", en: "ORIGINAL")
        case .preview: return preferences.text(ar: "المعاينة", en: "PREVIEW")
        case .export: return preferences.text(ar: "الناتج", en: "EXPORT")
        }
    }

    private func previewModeButton(_ mode: PreviewMode, title: String) -> some View {
        let selected = previewMode == mode
        return Button {
            previewMode = mode
        } label: {
            VStack(spacing: 5) {
                Text(title)
                    .font(IrfaaliTypography.captionStrong)
                    .foregroundStyle(selected ? Color.primary : Color.secondary)

                Rectangle()
                    .fill(selected ? IrfaaliVisual.electricCyan : Color.clear)
                    .frame(height: 1)
            }
        }
        .buttonStyle(V3PressStyle())
    }

    // MARK: - Analysis

    private var analysisLoadingSection: some View {
        section(title: preferences.text(ar: "تحليل الفيديو", en: "Video analysis")) {
            HStack(spacing: 12) {
                IrfaaliMiniActivity()
                VStack(alignment: .leading, spacing: 3) {
                    Text(preferences.text(ar: model.analysisStageTextArabic, en: model.analysisStageTextEnglish))
                        .font(IrfaaliTypography.control)
                    Text(preferences.text(ar: "نقرأ الملف ثم نفحص عينات من اللقطات.", en: "Reading the file, then inspecting sampled frames."))
                        .font(IrfaaliTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var analysisSection: some View {
        section(title: preferences.text(ar: "تحليل الفيديو", en: "Video analysis")) {
            if model.isAnalyzing {
                HStack(spacing: 12) {
                    IrfaaliMiniActivity()
                    VStack(alignment: .leading, spacing: 3) {
                        Text(preferences.text(ar: model.analysisStageTextArabic, en: model.analysisStageTextEnglish))
                            .font(IrfaaliTypography.control)
                        Text(preferences.text(ar: "التحليل لا يغيّر الفيديو.", en: "Analysis does not alter the video."))
                            .font(IrfaaliTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let report = model.analysisReport {
                if report.sampledFrameCount == 0 {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(preferences.text(ar: "تحليل محافظ", en: "Conservative analysis"))
                            .font(IrfaaliTypography.control)
                        Text(preferences.text(ar: "تعذر فحص الصورة فريمًا بفريم، لذلك لم نفترض عيوبًا غير مؤكدة.", en: "Frame sampling was unavailable, so no unmeasured defects were assumed."))
                            .font(IrfaaliTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 0) {
                        findingRow(preferences.text(ar: "الإضاءة", en: "Exposure"), exposureLabel(report), signal: exposureSignal(report))
                        IrfaaliHairline()
                        findingRow(preferences.text(ar: "التفاصيل", en: "Detail"), sharpnessLabel(report), signal: report.sharpnessScore)
                        IrfaaliHairline()
                        findingRow(preferences.text(ar: "التشويش", en: "Noise"), severityLabel(report.noiseScore), signal: report.noiseScore)
                        IrfaaliHairline()
                        findingRow(preferences.text(ar: "آثار الضغط", en: "Compression"), severityLabel(report.compressionArtifactScore), signal: report.compressionArtifactScore)
                        IrfaaliHairline()
                        findingRow(preferences.text(ar: "الحركة", en: "Motion"), motionLabel(report.motionLevel), signal: report.motionScore)
                    }

                    Text(preferences.text(ar: "فُحصت \(report.sampledFrameCount) لقطات موزعة على مدة الفيديو.", en: "Measured \(report.sampledFrameCount) frames across the video."))
                        .font(IrfaaliTypography.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 11)
                }
            } else {
                Text(preferences.text(ar: "لا توجد نتيجة تحليل بعد.", en: "No analysis result yet."))
                    .font(IrfaaliTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func findingRow(_ title: String, _ value: String, signal: Double) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(IrfaaliTypography.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(IrfaaliTypography.control)
            }

            Spacer()

            Capsule()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 54, height: 3)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(IrfaaliVisual.electricCyan.opacity(0.76))
                        .frame(width: max(4, 54 * min(max(signal, 0), 1)), height: 3)
                }
        }
        .frame(minHeight: 54)
    }

    // MARK: - Recommendation

    private func recommendationSection(_ recommendation: VideoRecommendation) -> some View {
        section(title: preferences.text(ar: "التوصية", en: "Recommendation")) {
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(recommendation.title(isArabic: preferences.isArabic))
                        .font(IrfaaliTypography.groupTitle)

                    Text(recommendation.explanation(isArabic: preferences.isArabic))
                        .font(IrfaaliTypography.secondaryBody)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                recommendationMetrics(recommendation)

                Button {
                    model.applyRecommendedSettings()
                    previewMode = .preview
                } label: {
                    HStack {
                        Text(recommendationApplied ? preferences.text(ar: "تم تطبيق التوصية", en: "Recommendation applied") : preferences.text(ar: "تطبيق التوصية", en: "Apply recommendation"))
                            .font(IrfaaliTypography.button)
                        Spacer()
                        Image(systemName: recommendationApplied ? "checkmark" : (preferences.isArabic ? "arrow.left" : "arrow.right"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(IrfaaliVisual.electricCyan)
                    }
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(V3PressStyle())
                .disabled(recommendationApplied || model.isProcessing)
                .overlay(alignment: .top) { IrfaaliHairline() }
            }
        }
    }

    private func recommendationMetrics(_ recommendation: VideoRecommendation) -> some View {
        HStack(spacing: 0) {
            metric(preferences.text(ar: "الدقة", en: "Resolution"), recommendation.processing.resolution.title(isArabic: preferences.isArabic))
            metric(preferences.text(ar: "الحركة", en: "Motion"), recommendation.processing.frameRate.title(isArabic: preferences.isArabic))
            metric(preferences.text(ar: "الترميم", en: "Restoration"), recommendation.enhancement.mode.title(isArabic: preferences.isArabic))
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(IrfaaliTypography.caption)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(IrfaaliTypography.metadataMonospaced)
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
        section(title: preferences.text(ar: "النتيجة", en: "Output")) {
            VStack(alignment: .leading, spacing: 22) {
                selectorGroup(title: preferences.text(ar: "الدقة", en: "Resolution"), value: model.settings.resolution.title(isArabic: preferences.isArabic)) {
                    horizontalOptions {
                        ForEach(VideoProcessingSettings.supportedResolutions(for: info)) { resolution in
                            optionButton(resolution.title(isArabic: preferences.isArabic), selected: model.settings.resolution == resolution) {
                                model.settings.resolution = resolution
                                previewMode = .preview
                            }
                        }
                    }
                }

                selectorGroup(title: preferences.text(ar: "معدل الإطارات", en: "Frame rate"), value: model.settings.frameRate.title(isArabic: preferences.isArabic)) {
                    horizontalOptions {
                        ForEach(VideoProcessingSettings.supportedFrameRates(for: info)) { frameRate in
                            optionButton(frameRate.title(isArabic: preferences.isArabic), selected: model.settings.frameRate == frameRate) {
                                model.settings.frameRate = frameRate
                                previewMode = .preview
                            }
                        }
                    }
                }

                targetSummary(info)

                if let note = outputNote(info) {
                    Text(note)
                        .font(IrfaaliTypography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .disabled(model.isProcessing)
    }

    @ViewBuilder
    private func selectorGroup<Content: View>(title: String, value: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(IrfaaliTypography.captionStrong)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(value)
                    .font(IrfaaliTypography.metadataMonospaced)
                    .foregroundStyle(.secondary)
            }
            content()
        }
    }

    @ViewBuilder
    private func horizontalOptions<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) { content() }
        }
        .scrollIndicators(.hidden)
    }

    private func optionButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(IrfaaliTypography.metadataMonospaced)
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .padding(.horizontal, 13)
                .frame(minHeight: 38)
                .background(selected ? selectedFill : Color.clear, in: Capsule())
                .overlay {
                    Capsule().stroke(selected ? IrfaaliVisual.electricCyan.opacity(0.34) : surfaceStroke, lineWidth: 0.6)
                }
        }
        .buttonStyle(V3PressStyle())
    }

    private func targetSummary(_ info: VideoAssetInfo) -> some View {
        let size = model.settings.targetSize(for: info)
        let targetFPS = model.settings.frameRate.requestedFPS ?? info.sourceFPS
        let isUpscale = max(size.width, size.height) > CGFloat(max(info.width, info.height))
        let interpolates = targetFPS > info.sourceFPS + 0.5

        return VStack(alignment: .leading, spacing: 10) {
            IrfaaliHairline()

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preferences.text(ar: "المخرج المتوقع", en: "Expected output"))
                        .font(IrfaaliTypography.captionStrong)
                        .foregroundStyle(.tertiary)

                    Text("\(Int(size.width))×\(Int(size.height))")
                        .font(IrfaaliTypography.title)
                        .monospacedDigit()

                    Text("\(IrfaaliFormatters.fps(targetFPS)) · \(model.settings.codec.title(isArabic: preferences.isArabic))")
                        .font(IrfaaliTypography.metadataMonospaced)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    if isUpscale { truthBadge(preferences.text(ar: "رفع دقة", en: "UPSCALE")) }
                    if interpolates { truthBadge(preferences.text(ar: "معالجة حركة", en: "MOTION")) }
                }
            }
        }
    }

    private func truthBadge(_ text: String) -> some View {
        Text(text)
            .font(IrfaaliTypography.captionStrong)
            .foregroundStyle(IrfaaliVisual.electricCyan)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(IrfaaliVisual.electricCyan.opacity(colorScheme == .dark ? 0.10 : 0.08), in: Capsule())
    }

    // MARK: - Restoration

    private func restorationSection(_ info: VideoAssetInfo) -> some View {
        section(title: preferences.text(ar: "الترميم", en: "Restoration")) {
            DisclosureGroup(isExpanded: $restorationExpanded) {
                VStack(alignment: .leading, spacing: 20) {
                    horizontalOptions {
                        ForEach(VideoEnhancementSettings.Mode.allCases.filter { $0 != .custom }) { mode in
                            optionButton(mode.title(isArabic: preferences.isArabic), selected: model.enhancement.mode == mode) {
                                model.applyEnhancementMode(mode)
                                previewMode = .preview
                            }
                        }
                    }

                    if model.enhancement.mode != .off {
                        restorationSlider(preferences.text(ar: "تنظيف التشويش", en: "Noise cleanup"), keyPath: \VideoEnhancementSettings.denoise)
                        restorationSlider(preferences.text(ar: "استعادة التفاصيل", en: "Detail recovery"), keyPath: \VideoEnhancementSettings.detailRecovery)
                        restorationSlider(preferences.text(ar: "الحدة", en: "Sharpening"), keyPath: \VideoEnhancementSettings.sharpening)
                        restorationSlider(preferences.text(ar: "حيوية اللون", en: "Color"), keyPath: \VideoEnhancementSettings.colorBoost)

                        DisclosureGroup(preferences.text(ar: "الضوء والتباين", en: "Light & contrast")) {
                            VStack(spacing: 18) {
                                restorationSlider(preferences.text(ar: "الإضاءة", en: "Exposure"), keyPath: \VideoEnhancementSettings.exposure, range: -1...1)
                                restorationSlider(preferences.text(ar: "التباين", en: "Contrast"), keyPath: \VideoEnhancementSettings.contrast, range: -1...1)
                            }
                            .padding(.top, 14)
                        }
                        .font(IrfaaliTypography.captionStrong)
                        .tint(.secondary)
                    }

                    Text(preferences.text(ar: "ابدأ بأقل معالجة ممكنة. الهدف هو إصلاح العيب مع الحفاظ على طبيعة اللقطة.", en: "Use the least treatment necessary. Repair the defect while preserving the character of the footage."))
                        .font(IrfaaliTypography.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 16)
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(preferences.text(ar: "معالجة الصورة", en: "Image treatment"))
                            .font(IrfaaliTypography.control)
                        Text(model.enhancement.mode.title(isArabic: preferences.isArabic))
                            .font(IrfaaliTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .tint(.secondary)
        }
        .disabled(model.isProcessing)
    }

    private func restorationSlider(
        _ title: String,
        keyPath: WritableKeyPath<VideoEnhancementSettings, Double>,
        range: ClosedRange<Double> = 0...1
    ) -> some View {
        let value = model.enhancement[keyPath: keyPath]
        let displayValue = Int((value * 100).rounded())

        return VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(IrfaaliTypography.captionStrong)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(displayValue)%")
                    .font(IrfaaliTypography.metadataMonospaced)
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { model.enhancement[keyPath: keyPath] },
                    set: { newValue in
                        model.updateEnhancement(keyPath, value: newValue)
                        previewMode = .preview
                    }
                ),
                in: range
            )
            .tint(IrfaaliVisual.electricCyan)
        }
    }

    // MARK: - Advanced

    private func advancedSection(_ info: VideoAssetInfo) -> some View {
        section(title: preferences.text(ar: "المتقدم", en: "Advanced")) {
            DisclosureGroup(isExpanded: $advancedExpanded) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(preferences.text(ar: "الترميز", en: "Encoding"))
                            .font(IrfaaliTypography.captionStrong)
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
                                    .font(IrfaaliTypography.control)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(V3PressStyle())
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
                            .font(IrfaaliTypography.captionStrong)
                    }
                    .tint(.secondary)
                }
                .padding(.top, 16)
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(preferences.text(ar: "خيارات تقنية", en: "Technical options"))
                        .font(IrfaaliTypography.control)
                    Spacer()
                    Text(model.settings.codec.title(isArabic: preferences.isArabic))
                        .font(IrfaaliTypography.metadataMonospaced)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .tint(.secondary)
        }
        .disabled(model.isProcessing)
    }

    // MARK: - Processing

    private func processSection(_ info: VideoAssetInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.isProcessing {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preferences.text(ar: model.processingStageTextArabic, en: model.processingStageTextEnglish))
                            .font(IrfaaliTypography.control)
                        Text(processingSummary(info))
                            .font(IrfaaliTypography.metadataMonospaced)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(Int((model.progress * 100).rounded()))%")
                        .font(IrfaaliTypography.metadataMonospaced)
                }

                ProgressView(value: model.progress)
                    .tint(IrfaaliVisual.electricCyan)

                if model.canCancelProcessing {
                    Button { model.cancelProcessing() } label: {
                        Text(preferences.text(ar: "إلغاء المعالجة", en: "Cancel processing"))
                            .font(IrfaaliTypography.captionStrong)
                            .foregroundStyle(.red)
                            .frame(minHeight: 40)
                    }
                    .buttonStyle(V3PressStyle())
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
                                    .font(IrfaaliTypography.groupTitle)
                                Text(processingSummary(info))
                                    .font(IrfaaliTypography.metadataMonospaced)
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
                .buttonStyle(V3PressStyle())
                .disabled(!model.canProcess)

                if model.needsFrameGeneration, model.frameGenerationReadiness?.canStart == false {
                    Text(preferences.text(ar: "معالجة معدل الإطارات غير متاحة الآن بحالة الجهاز أو حجم الفيديو الحالي.", en: "Frame-rate processing is unavailable with the current device state or video size."))
                        .font(IrfaaliTypography.caption)
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
        section(title: preferences.text(ar: "الناتج", en: "Result")) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preferences.text(ar: "الفيديو جاهز", en: "Video ready"))
                            .font(IrfaaliTypography.groupTitle)
                        if let output = model.outputInfo {
                            Text("\(output.width)×\(output.height) · \(IrfaaliFormatters.fps(output.sourceFPS)) · \(output.videoCodec)")
                                .font(IrfaaliTypography.metadataMonospaced)
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
                        comparisonColumn(preferences.text(ar: "قبل", en: "Before"), resolution: "\(source.width)×\(source.height)", fps: IrfaaliFormatters.fps(source.sourceFPS), codec: source.videoCodec)
                        Rectangle().fill(surfaceStroke).frame(width: 0.5, height: 56)
                        comparisonColumn(preferences.text(ar: "بعد", en: "After"), resolution: "\(output.width)×\(output.height)", fps: IrfaaliFormatters.fps(output.sourceFPS), codec: output.videoCodec)
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        Task { await model.saveOutputToPhotos() }
                    } label: {
                        saveButtonLabel
                    }
                    .buttonStyle(V3FilledButtonStyle())
                    .disabled(model.saveState == .saving || model.saveState == .saved)

                    ShareLink(item: outcome.url) {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: 46, height: 46)
                    }
                    .buttonStyle(V3SecondaryButtonStyle())
                }

                if case .failed(let message) = model.saveState {
                    Text(message)
                        .font(IrfaaliTypography.caption)
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

    private func comparisonColumn(_ title: String, resolution: String, fps: String, codec: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(IrfaaliTypography.captionStrong)
                .foregroundStyle(.tertiary)
            Text(resolution)
                .font(IrfaaliTypography.control)
                .monospacedDigit()
            Text("\(fps) · \(codec)")
                .font(IrfaaliTypography.metadataMonospaced)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Shared

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased(with: preferences.locale))
                .font(IrfaaliTypography.captionStrong)
                .tracking(preferences.isArabic ? 0.15 : 1.05)
                .foregroundStyle(.tertiary)
            content()
        }
        .padding(.top, 2)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(IrfaaliTypography.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 10)
            Text(value)
                .font(IrfaaliTypography.metadataMonospaced)
                .foregroundStyle(.primary.opacity(0.84))
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
                .font(IrfaaliTypography.secondaryBody)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) { IrfaaliHairline() }
    }

    private var surfaceFill: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.045 : 0.025)
    }

    private var surfaceStroke: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.13 : 0.10)
    }

    private var selectedFill: Color {
        IrfaaliVisual.electricCyan.opacity(colorScheme == .dark ? 0.10 : 0.08)
    }

    private func outputNote(_ info: VideoAssetInfo) -> String? {
        let target = model.settings.targetSize(for: info)
        let upscales = max(target.width, target.height) > CGFloat(max(info.width, info.height))
        var notes: [String] = []

        if upscales {
            notes.append(preferences.text(ar: "رفع الدقة يزيد حجم الإخراج، لكنه لا يحوّل التفاصيل المفقودة إلى تفاصيل أصلية.", en: "Upscaling increases output dimensions, but it does not turn missing detail into native detail."))
        }

        if model.needsFrameGeneration {
            notes.append(preferences.text(ar: "رفع معدل الإطارات يعتمد على تقدير الحركة ويحتاج معالجة إضافية.", en: "Higher frame rates rely on motion estimation and require additional processing."))
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
        guard let codec = info.audioCodec else { return preferences.text(ar: "بدون صوت", en: "No audio") }
        let channels = info.audioChannels.map { "\($0)ch" } ?? ""
        let sampleRate = info.audioSampleRate.map { String(format: "%.1fkHz", $0 / 1000) } ?? ""
        return [codec, channels, sampleRate].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func exposureLabel(_ report: VideoAnalysisReport) -> String {
        if report.isHighlightLimited { return preferences.text(ar: "إضاءات قوية", en: "Highlight limited") }
        if report.isLowLight { return preferences.text(ar: "منخفضة", en: "Low") }
        return preferences.text(ar: "متوازنة", en: "Balanced")
    }

    private func exposureSignal(_ report: VideoAnalysisReport) -> Double {
        if report.isHighlightLimited { return min(1, report.highlightClippingRatio * 8) }
        if report.isLowLight { return min(1, report.shadowClippingRatio * 4 + max(0, 0.30 - report.averageLuminance)) }
        return 0.22
    }

    private func sharpnessLabel(_ report: VideoAnalysisReport) -> String {
        report.isSoft ? preferences.text(ar: "ناعمة", en: "Soft") : preferences.text(ar: "جيدة", en: "Good")
    }

    private func severityLabel(_ score: Double) -> String {
        switch score {
        case ..<0.14: return preferences.text(ar: "خفيف", en: "Low")
        case ..<0.30: return preferences.text(ar: "متوسط", en: "Moderate")
        default: return preferences.text(ar: "مرتفع", en: "High")
        }
    }

    private func motionLabel(_ level: VideoAnalysisReport.MotionLevel) -> String {
        switch level {
        case .low: return preferences.text(ar: "هادئة", en: "Low")
        case .medium: return preferences.text(ar: "متوسطة", en: "Moderate")
        case .high: return preferences.text(ar: "سريعة", en: "Fast")
        }
    }

    // MARK: - Import

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
        defer { if access { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
        let localURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("irfaali-v3-\(UUID().uuidString).\(ext)")

        do {
            try FileManager.default.copyItem(at: url, to: localURL)
            await model.importVideo(url: localURL)
        } catch {
            model.errorMessage = AppErrorMessage.describe(error, isArabic: preferences.isArabic)
        }
    }
}

private struct V3PressStyle: ButtonStyle {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.80 : 1)
            .scaleEffect(configuration.isPressed && preferences.animationsEnabled && !reduceMotion ? 0.98 : 1)
            .animation(preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.10) : nil, value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { oldValue, newValue in
                preferences.hapticsEnabled && !oldValue && newValue
            }
    }
}

private struct V3FilledButtonStyle: ButtonStyle {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(IrfaaliTypography.button)
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(
                Color.primary.opacity(configuration.isPressed ? 0.14 : (colorScheme == .dark ? 0.085 : 0.055)),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .scaleEffect(configuration.isPressed && preferences.animationsEnabled && !reduceMotion ? 0.98 : 1)
            .animation(preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.10) : nil, value: configuration.isPressed)
    }
}

private struct V3SecondaryButtonStyle: ButtonStyle {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(IrfaaliTypography.button)
            .background(
                Color.primary.opacity(configuration.isPressed ? 0.08 : (colorScheme == .dark ? 0.035 : 0.022)),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .scaleEffect(configuration.isPressed && preferences.animationsEnabled && !reduceMotion ? 0.98 : 1)
            .animation(preferences.animationsEnabled && !reduceMotion ? .easeInOut(duration: 0.10) : nil, value: configuration.isPressed)
    }
}
