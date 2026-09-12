import PhotosUI
import SwiftData
import SwiftUI

struct StudioView: View {
    @StateObject private var model = StudioViewModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var showFileImporter = false

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var preferences: AppPreferences

    var body: some View {
        ZStack {
            ThemeBackground()

            ScrollView {
                VStack(spacing: 18) {
                    hero

                    if model.isAnalyzing {
                        analyzingCard
                    }

                    if let info = model.info {
                        sourceCard(info)
                        processingCard(info)
                    }

                    if let outcome = model.lastOutcome {
                        successCard(outcome)
                    }

                    if let message = model.validationMessage {
                        warningCard(message)
                    }

                    if let message = model.errorMessage {
                        errorCard(message)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 42)
            }
        }
        .navigationTitle(AppBranding.appName)
        .navigationBarTitleDisplayMode(.large)
        .sensoryFeedback(.success, trigger: model.lastOutcome?.url) { _, _ in
            preferences.hapticsEnabled
        }
        .sensoryFeedback(.success, trigger: model.saveState == .saved) { _, _ in
            preferences.hapticsEnabled
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

    private var hero: some View {
        PremiumSurface {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(preferences.text(ar: "محرك ارفعلي", en: "IRFAALI ENGINE"))
                            .font(.caption2.weight(.bold))
                            .tracking(preferences.isArabic ? 0.3 : 2.2)
                            .foregroundStyle(IrfaaliTheme.accent)

                        Text(preferences.text(ar: "ارفع فيديو يا وحش 🔥", en: "Drop in a video."))
                            .font(IrfaaliTheme.titleFont(30))

                        Text(
                            preferences.text(
                                ar: "نفحص المصدر أول، وبعدها أنت تتحكم بالدقة والفريمات والترميز والتحسين. كل نتيجة نرجع نفحصها بعد التصدير.",
                                en: "We inspect the source first, then you control resolution, frame rate, codec and enhancement. Every export is verified again after processing."
                            )
                        )
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 6)

                    ZStack {
                        Circle()
                            .fill(IrfaaliTheme.accent.opacity(0.12))
                            .frame(width: 54, height: 54)

                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 43, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(IrfaaliTheme.accent)
                    }
                }

                HStack(spacing: 8) {
                    statusPill(icon: "bolt.fill", ar: "محلي", en: "ON DEVICE")
                    statusPill(icon: "lock.fill", ar: "خصوصي", en: "PRIVATE")
                    statusPill(icon: "sparkles", ar: "مجاني", en: "FREE")
                }

                HStack(spacing: 10) {
                    PhotosPicker(selection: $photoItem, matching: .videos) {
                        Label(
                            preferences.text(ar: "اختار فيديو", en: "Choose Video"),
                            systemImage: "photo.on.rectangle.angled"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PremiumPrimaryButtonStyle())

                    Button {
                        showFileImporter = true
                    } label: {
                        Image(systemName: "folder.fill")
                            .frame(width: 48, height: 48)
                    }
                    .accessibilityLabel(preferences.text(ar: "اختيار من الملفات", en: "Choose from Files"))
                    .buttonStyle(PremiumSecondaryButtonStyle())
                }
            }
        }
        .padding(.top, 8)
    }

    private func statusPill(icon: String, ar: String, en: String) -> some View {
        Label(preferences.text(ar: ar, en: en), systemImage: icon)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(IrfaaliTheme.accent.opacity(0.09), in: Capsule())
            .foregroundStyle(.secondary)
    }

    private var analyzingCard: some View {
        PremiumSurface {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(IrfaaliTheme.accent.opacity(0.16), lineWidth: 5)
                        .frame(width: 46, height: 46)
                    ProgressView()
                        .tint(IrfaaliTheme.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(preferences.text(ar: "ثواني ونفصفصه لك 👀", en: "Reading the real video data…"))
                        .font(.headline.weight(.bold))

                    Text(
                        preferences.text(
                            ar: "نقرأ التراكات، الكودك، FPS، البت ريت، الصوت والحاوية.",
                            en: "Inspecting tracks, codec, FPS, bitrate, audio and container."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    private func sourceCard(_ info: VideoAssetInfo) -> some View {
        PremiumSurface {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preferences.text(ar: "فحص المصدر", en: "Source Scan"))
                            .font(.title3.bold())
                        Text(info.fileName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(info.dynamicRange)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(IrfaaliTheme.accent.opacity(0.12), in: Capsule())
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    MetricTile(
                        icon: "rectangle.portrait",
                        title: preferences.text(ar: "الدقة", en: "Resolution"),
                        value: "\(info.width)×\(info.height)"
                    )
                    MetricTile(icon: "speedometer", title: "FPS", value: IrfaaliFormatters.fps(info.sourceFPS))
                    MetricTile(
                        icon: "film.stack",
                        title: preferences.text(ar: "الكودك", en: "Video Codec"),
                        value: info.videoCodec
                    )
                    MetricTile(
                        icon: "waveform",
                        title: preferences.text(ar: "البت ريت", en: "Video Bitrate"),
                        value: IrfaaliFormatters.bitrate(info.estimatedBitrate)
                    )
                    MetricTile(
                        icon: "clock",
                        title: preferences.text(ar: "المدة", en: "Duration"),
                        value: IrfaaliFormatters.duration(info.duration)
                    )
                    MetricTile(
                        icon: "internaldrive",
                        title: preferences.text(ar: "الحجم", en: "Size"),
                        value: IrfaaliFormatters.byteCount.string(fromByteCount: info.fileSizeBytes)
                    )
                    MetricTile(
                        icon: "shippingbox",
                        title: preferences.text(ar: "الحاوية", en: "Container"),
                        value: info.container
                    )
                    MetricTile(
                        icon: "speaker.wave.2",
                        title: preferences.text(ar: "الصوت", en: "Audio"),
                        value: audioSummary(info)
                    )
                }

                Divider().opacity(0.22)
                compatibilityRow(info)
            }
        }
    }

    private func processingCard(_ info: VideoAssetInfo) -> some View {
        PremiumSurface {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(IrfaaliTheme.accent.opacity(0.12))
                        Image(systemName: "slider.horizontal.3")
                            .font(.headline.bold())
                            .foregroundStyle(IrfaaliTheme.accent)
                    }
                    .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(preferences.text(ar: "غرفة التحكم", en: "Processing Studio"))
                            .font(.headline.weight(.bold))
                        Text(preferences.text(ar: "مو أسماء وهمية — هذي إعدادات الملف الناتج.", en: "These settings drive the actual output file."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        withAnimation(preferences.animationsEnabled ? .snappy : nil) {
                            model.applyRecommendedSettings()
                        }
                    } label: {
                        Image(systemName: "wand.and.stars")
                            .font(.headline)
                            .frame(width: 38, height: 38)
                    }
                    .buttonStyle(PremiumSecondaryButtonStyle())
                    .accessibilityLabel(preferences.text(ar: "اختيار ذكي", en: "Smart Setup"))
                    .disabled(model.isProcessing)
                    .opacity(model.isProcessing ? 0.45 : 1)
                }

                settingsDivider

                settingHeader(icon: "rectangle.expand.vertical", ar: "الدقة النهائية", en: "Output Resolution")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 8) {
                    ForEach(VideoProcessingSettings.Resolution.allCases) { resolution in
                        settingChoice(
                            title: resolution.title(isArabic: preferences.isArabic),
                            selected: model.settings.resolution == resolution,
                            enabled: !model.isProcessing
                        ) {
                            model.settings.resolution = resolution
                        }
                    }
                }

                settingHeader(icon: "speedometer", ar: "الفريمات", en: "Frame Rate")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 8)], spacing: 8) {
                    ForEach(VideoProcessingSettings.FrameRate.allCases) { frameRate in
                        let needsAI = frameRate.requestedFPS.map { $0 > info.sourceFPS + 0.5 } ?? false

                        settingChoice(
                            title: frameRate.title(isArabic: preferences.isArabic),
                            selected: model.settings.frameRate == frameRate,
                            enabled: !model.isProcessing,
                            badge: needsAI ? "AI 2×" : nil
                        ) {
                            model.settings.frameRate = frameRate
                        }
                    }
                }

                if model.needsFrameGeneration {
                    aiFrameNotice(info)
                }

                settingHeader(icon: "cpu", ar: "الترميز", en: "Codec")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                    ForEach(VideoProcessingSettings.Codec.allCases) { codec in
                        settingChoice(
                            title: codec.title(isArabic: preferences.isArabic),
                            selected: model.settings.codec == codec,
                            enabled: !model.isProcessing
                        ) {
                            model.settings.codec = codec
                        }
                    }
                }

                settingsDivider

                settingHeader(icon: "wand.and.rays", ar: "تحسين الصورة", en: "Image Enhancement")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 8)], spacing: 8) {
                    ForEach(VideoEnhancementSettings.Mode.allCases) { mode in
                        settingChoice(
                            title: mode.title(isArabic: preferences.isArabic),
                            selected: model.enhancement.mode == mode,
                            enabled: !model.isProcessing,
                            badge: mode == .smart ? "AUTO" : nil
                        ) {
                            model.applyEnhancementMode(mode)
                        }
                    }
                }

                if model.enhancement.isEnabled {
                    enhancementControls
                }

                outputTargetCard(info)

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
                                    codec: finalInfo.videoCodec
                                )
                                modelContext.insert(record)
                                try? modelContext.save()
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "sparkles.rectangle.stack.fill")
                            Text(preferences.text(ar: "يلا اضبطه 🔥", en: "Process Video"))
                            Spacer()
                            Image(systemName: preferences.isArabic ? "arrow.left" : "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PremiumPrimaryButtonStyle())
                    .disabled(!model.canProcess)
                    .opacity(model.canProcess ? 1 : 0.48)
                }
            }
        }
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(.secondary.opacity(0.14))
            .frame(height: 1)
    }

    private func settingHeader(icon: String, ar: String, en: String) -> some View {
        Label(preferences.text(ar: ar, en: en), systemImage: icon)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.primary)
    }

    private func settingChoice(
        title: String,
        selected: Bool,
        enabled: Bool,
        badge: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard enabled else { return }
            withAnimation(preferences.animationsEnabled ? .snappy : nil) {
                action()
            }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                if let badge {
                    Text(badge)
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(IrfaaliTheme.accent.opacity(0.16), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .padding(.horizontal, 8)
            .background(
                selected ? IrfaaliTheme.accent.opacity(0.18) : Color.primary.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? IrfaaliTheme.accent.opacity(0.62) : .secondary.opacity(0.12), lineWidth: 1)
            }
            .foregroundStyle(enabled ? (selected ? IrfaaliTheme.accent : .primary) : .secondary)
            .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var enhancementControls: some View {
        VStack(spacing: 12) {
            enhancementSlider(icon: "drop.degreesign", ar: "تنظيف التشويش", en: "Noise Cleanup", keyPath: \VideoEnhancementSettings.denoise)
            enhancementSlider(icon: "viewfinder", ar: "استرجاع التفاصيل", en: "Detail Recovery", keyPath: \VideoEnhancementSettings.detailRecovery)
            enhancementSlider(icon: "scope", ar: "الحدة", en: "Sharpening", keyPath: \VideoEnhancementSettings.sharpening)
            enhancementSlider(icon: "circle.lefthalf.filled", ar: "حيوية اللون", en: "Color Boost", keyPath: \VideoEnhancementSettings.colorBoost)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(IrfaaliTheme.accent)
                Text(
                    preferences.text(
                        ar: "هذي معالجة فعلية على كل فريم باستخدام Core Image. إذا حركت أي سلايدر يتحول الوضع إلى يدوي تلقائي.",
                        en: "These controls run a real per-frame Core Image pass. Moving any slider switches the profile to Custom automatically."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(IrfaaliTheme.accent.opacity(0.065), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
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
                    .contentTransition(.numericText())
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

    private func aiFrameNotice(_ info: VideoAssetInfo) -> some View {
        let requestedFPS = model.settings.frameRate.requestedFPS ?? info.sourceFPS
        let plan = model.frameGenerationPlan
        let readiness = model.frameGenerationReadiness
        let isSupported2x = plan?.strategy == .opticalFlow2x
        let tone: Color = readiness?.level == .blocked ? .red : .orange

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tone.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "brain.head.profile.fill")
                        .font(.title3)
                        .foregroundStyle(tone)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(preferences.text(ar: "Frame Generation حقيقي 🧠⚡️", en: "Real Frame Generation 🧠⚡️"))
                        .font(.subheadline.bold())

                    Text(
                        preferences.text(
                            ar: isSupported2x
                                ? "المسار \(Int(info.sourceFPS.rounded()))→\(Int(requestedFPS.rounded())) مبني فعلًا: Vision Optical Flow + Metal Motion Warp + ترميز فريمات جديدة. ما فيه تكرار فريمات."
                                : "المسار \(Int(info.sourceFPS.rounded()))→\(Int(requestedFPS.rounded())) مو من مسارات 2× المدعومة في v1، لذلك ما راح نزور النتيجة.",
                            en: isSupported2x
                                ? "The \(Int(info.sourceFPS.rounded()))→\(Int(requestedFPS.rounded())) path is genuinely implemented with Vision optical flow, Metal motion warp and newly encoded frames — no duplication trick."
                                : "The \(Int(info.sourceFPS.rounded()))→\(Int(requestedFPS.rounded())) path is not a supported 2× v1 route, so Irfaali will not fake the result."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                generationStatusPill(
                    text: isSupported2x ? "ENGINE WIRED" : "UNSUPPORTED RATIO",
                    systemImage: isSupported2x ? "cpu.fill" : "xmark.circle.fill",
                    tone: tone
                )

                if let readiness {
                    generationStatusPill(
                        text: readiness.level == .ready ? "DEVICE READY" : readiness.level == .caution ? "DEVICE CHECK" : "DEVICE BLOCK",
                        systemImage: readiness.level == .blocked ? "exclamationmark.triangle.fill" : "iphone.gen3",
                        tone: readiness.level == .ready ? IrfaaliTheme.accent : tone
                    )
                }

                generationStatusPill(text: "QA LOCK", systemImage: "lock.fill", tone: .secondary)
            }

            if let readiness, !readiness.reasons.isEmpty {
                Text(readiness.reasons.map(\.description).joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(readiness.level == .blocked ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(
                preferences.text(
                    ar: "المحرك مربوط داخليًا، لكن زر التصدير العالي مقفول مؤقتًا لين نخلص اختبار الآيفون الحقيقي: جودة الحركة، الحرارة، الذاكرة وتزامن الصوت.",
                    en: "The engine is wired internally, but public high-FPS export stays QA-locked until real-iPhone motion quality, thermals, memory and audio-sync checks pass."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(tone.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tone.opacity(0.16), lineWidth: 1)
        }
    }

    private func generationStatusPill(text: String, systemImage: String, tone: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 9, weight: .black, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(tone.opacity(0.09), in: Capsule())
            .foregroundStyle(tone)
    }

    private func outputTargetCard(_ info: VideoAssetInfo) -> some View {
        let size = model.settings.targetSize(for: info)
        let requestedFPS = model.settings.frameRate.requestedFPS ?? info.sourceFPS
        let needsGeneration = requestedFPS > info.sourceFPS + 0.5

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(IrfaaliTheme.accent.opacity(0.11))
                Image(systemName: needsGeneration ? "sparkles.rectangle.stack.fill" : "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(IrfaaliTheme.accent)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(preferences.text(ar: needsGeneration ? "الهدف المطلوب" : "الهدف الحقيقي", en: needsGeneration ? "Requested Target" : "Verified Target"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Text("\(Int(size.width))×\(Int(size.height)) · \(IrfaaliFormatters.fps(requestedFPS))")
                    .font(.headline.monospacedDigit())

                HStack(spacing: 6) {
                    Text(model.settings.codec.title(isArabic: preferences.isArabic))
                    if needsGeneration {
                        Text("•")
                        Text("AI 2×")
                    }
                    if model.enhancement.isEnabled {
                        Text("•")
                        Text(model.enhancement.mode.title(isArabic: preferences.isArabic))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(13)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var processingProgress: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(IrfaaliTheme.accent.opacity(0.12), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: max(0.04, model.progress))
                        .stroke(IrfaaliTheme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: processingStageIcon)
                        .font(.headline.bold())
                        .foregroundStyle(IrfaaliTheme.accent)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(preferences.text(ar: model.processingStageTextArabic, en: model.processingStageTextEnglish))
                        .font(.subheadline.bold())
                    Text(processingStageCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(Int(model.progress * 100))%")
                    .font(.headline.monospacedDigit().bold())
                    .foregroundStyle(IrfaaliTheme.accent)
                    .contentTransition(.numericText())
            }

            ProgressView(value: model.progress)
                .tint(IrfaaliTheme.accent)

            if model.generatedFrameCount > 0 {
                Label(
                    preferences.text(
                        ar: "ولدنا \(model.generatedFrameCount) فريم جديد فعليًا",
                        en: "\(model.generatedFrameCount) new frames synthesized"
                    ),
                    systemImage: "square.stack.3d.up.fill"
                )
                .font(.caption.bold())
                .foregroundStyle(IrfaaliTheme.accent)
            }

            if model.sceneCutFallbackFrameCount > 0 {
                Label(
                    preferences.text(
                        ar: "حمينا \(model.sceneCutFallbackFrameCount) فريم عند قصّات المشاهد",
                        en: "\(model.sceneCutFallbackFrameCount) scene-cut cadence frames protected"
                    ),
                    systemImage: "scissors"
                )
                .font(.caption.bold())
                .foregroundStyle(.orange)
            }

            Text(preferences.text(ar: "ما نعتمد النتيجة لين نحلل الملف النهائي ونتأكد منه.", en: "The result is not accepted until the final file is analyzed and verified."))
                .font(.caption)
                .foregroundStyle(.secondary)

            if model.canCancelProcessing {
                Button {
                    model.cancelProcessing()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text(preferences.text(ar: "وقف العملية", en: "Cancel Processing"))
                        Spacer()
                        Text(preferences.text(ar: "بننظف الملفات الناقصة", en: "Partial files are cleaned"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PremiumDestructiveButtonStyle())
            }
        }
        .padding(14)
        .background(IrfaaliTheme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var processingStageIcon: String {
        switch model.processingStage {
        case .idle: return "bolt.fill"
        case .preparing: return "gearshape.2.fill"
        case .exporting: return "film.stack.fill"
        case .generatingFrames: return "brain.head.profile.fill"
        case .enhancing: return "wand.and.stars"
        case .verifying: return "checkmark.shield.fill"
        case .complete: return "checkmark.seal.fill"
        }
    }

    private var processingStageCaption: String {
        switch model.processingStage {
        case .idle:
            return preferences.text(ar: "المحرك واقف على أهبة الاستعداد", en: "Engine standing by")
        case .preparing:
            return preferences.text(ar: "نجهز المسارات والملف", en: "Preparing tracks and output")
        case .exporting:
            return preferences.text(ar: "الدقة والترميز تحت الشغل", en: "Resolution and codec pass")
        case .generatingFrames:
            return preferences.text(ar: "Vision + Metal يشتغلون الحين", en: "Vision + Metal are synthesizing motion")
        case .enhancing:
            return preferences.text(ar: "تنظيف وتفاصيل على كل فريم", en: "Per-frame cleanup and detail pass")
        case .verifying:
            return preferences.text(ar: "نقرأ الناتج من جديد قبل نعتمده", en: "Re-reading output before acceptance")
        case .complete:
            return preferences.text(ar: "تم واعتمدنا الملف", en: "Output accepted")
        }
    }

    private func processingSummary(_ info: VideoAssetInfo) -> String {
        let size = model.settings.targetSize(for: info)
        let fps = model.settings.frameRate.requestedFPS ?? info.sourceFPS
        let base = "\(Int(size.width))×\(Int(size.height)) · \(IrfaaliFormatters.fps(fps)) · \(model.settings.codec.title(isArabic: preferences.isArabic))"
        guard model.enhancement.isEnabled else { return base }
        return "\(base) · \(model.enhancement.mode.title(isArabic: preferences.isArabic))"
    }

    private func compatibilityRow(_ info: VideoAssetInfo) -> some View {
        let compatible = info.isTikTokPostingAPIFPSCompatible && info.isTikTokPostingAPIResolutionCompatible

        return HStack(spacing: 12) {
            Image(systemName: compatible ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(compatible ? IrfaaliTheme.accent : .orange)

            VStack(alignment: .leading, spacing: 3) {
                Text("TikTok Content Posting API")
                    .font(.subheadline.bold())

                Text(
                    preferences.text(
                        ar: "فحص توافق النشر الرسمي: 23–60fps وأبعاد 360–4096 بكسل لكل محور.",
                        en: "Official posting compatibility check: 23–60fps and 360–4096 pixels per axis."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func successCard(_ outcome: ExportOutcome) -> some View {
        let actual = model.outputInfo?.sourceFPS
        let classification = actual.map { outcome.validatedClassification(actualOutputFPS: $0) } ?? outcome.fpsClassification

        return PremiumSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(
                        preferences.text(ar: "تم يا بطل ✨", en: "Done & Verified"),
                        systemImage: "checkmark.seal.fill"
                    )
                    .font(.headline.bold())
                    .foregroundStyle(IrfaaliTheme.accent)

                    Spacer()

                    if model.outputInfo != nil {
                        Text("VERIFIED")
                            .font(.caption2.bold())
                            .tracking(1.2)
                            .foregroundStyle(IrfaaliTheme.accent)
                    }
                }

                Text(classification.title)
                    .font(.title3.bold())

                Text(classification.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let verification = model.frameGenerationVerification, verification.passed {
                    Label(
                        preferences.text(
                            ar: "Frame Generation Verified · \(verification.generatedFrameCount) فريم جديد",
                            en: "Frame Generation Verified · \(verification.generatedFrameCount) new frames"
                        ),
                        systemImage: "checkmark.shield.fill"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(IrfaaliTheme.accent)
                }

                if let source = model.info, let output = model.outputInfo {
                    HStack(spacing: 10) {
                        ComparisonColumn(
                            title: preferences.text(ar: "قبل", en: "Before"),
                            resolution: "\(source.width)×\(source.height)",
                            fps: IrfaaliFormatters.fps(source.sourceFPS),
                            codec: source.videoCodec,
                            bitrate: IrfaaliFormatters.bitrate(source.estimatedBitrate)
                        )

                        ComparisonColumn(
                            title: preferences.text(ar: "بعد", en: "After"),
                            resolution: "\(output.width)×\(output.height)",
                            fps: IrfaaliFormatters.fps(output.sourceFPS),
                            codec: output.videoCodec,
                            bitrate: IrfaaliFormatters.bitrate(output.estimatedBitrate)
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
            Label(preferences.text(ar: "احفظه بالصور", en: "Save to Photos"), systemImage: "square.and.arrow.down")
                .frame(maxWidth: .infinity)
        case .saving:
            HStack {
                ProgressView()
                Text(preferences.text(ar: "ثواني…", en: "Saving…"))
            }
            .frame(maxWidth: .infinity)
        case .saved:
            Label(preferences.text(ar: "وصل عندك ✅", en: "Saved"), systemImage: "checkmark")
                .frame(maxWidth: .infinity)
        case .failed:
            Label(preferences.text(ar: "جرّب الحفظ مرة ثانية", en: "Try Again"), systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
        }
    }

    private func audioSummary(_ info: VideoAssetInfo) -> String {
        guard let codec = info.audioCodec else {
            return preferences.text(ar: "بدون صوت", en: "No Audio")
        }

        let channels = info.audioChannels.map { "\($0)ch" } ?? ""
        let rate = info.audioSampleRate.map { String(format: "%.1fkHz", $0 / 1000) } ?? ""
        return [codec, channels, rate]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func warningCard(_ message: String) -> some View {
        PremiumSurface {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
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

private struct ComparisonColumn: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let resolution: String
    let fps: String
    let codec: String
    let bitrate: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
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
                .minimumScaleFactor(0.8)
            Text(bitrate)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.68),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
}

private struct PremiumPrimaryButtonStyle: ButtonStyle {
    @EnvironmentObject private var preferences: AppPreferences

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .background(
                IrfaaliTheme.accent.opacity(configuration.isPressed ? 0.72 : 0.94),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .foregroundStyle(Color.black)
            .scaleEffect(configuration.isPressed && preferences.animationsEnabled ? 0.975 : 1)
            .animation(.easeOut(duration: preferences.animationsEnabled ? 0.15 : 0), value: configuration.isPressed)
    }
}

private struct PremiumSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var preferences: AppPreferences

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(
                colorScheme == .dark
                    ? Color.white.opacity(configuration.isPressed ? 0.11 : 0.065)
                    : Color.white.opacity(configuration.isPressed ? 0.92 : 0.72),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.07))
            }
            .foregroundStyle(.primary)
            .scaleEffect(configuration.isPressed && preferences.animationsEnabled ? 0.975 : 1)
    }
}

private struct PremiumDestructiveButtonStyle: ButtonStyle {
    @EnvironmentObject private var preferences: AppPreferences

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(
                Color.red.opacity(configuration.isPressed ? 0.16 : 0.085),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.red.opacity(configuration.isPressed ? 0.42 : 0.24), lineWidth: 1)
            }
            .foregroundStyle(.red)
            .scaleEffect(configuration.isPressed && preferences.animationsEnabled ? 0.975 : 1)
            .animation(.easeOut(duration: preferences.animationsEnabled ? 0.15 : 0), value: configuration.isPressed)
    }
}
