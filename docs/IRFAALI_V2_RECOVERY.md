# Irfaali V2 — Recovery & Rehabilitation Baseline

This document is the durable project handoff for Irfaali V2 so the project can be recovered without relying on a chat history.

## Known-good baseline

- Repository: `anas1213231/Irfaali`
- Stable source branch: `integration/splash-real-asset-20260916`
- Stable commit: `3536688b59c94e91235f1da3a5f7a6e84c231759`
- Commit purpose: finalized the real bundled splash asset filename at `Irfaali/Resources/IrfaaliSplash.mp4`
- Stable CI run: GitHub Actions run `35028297856` (`iOS CI`, run 302)
- Stable CI result: **success**
- Verified CI stages: splash source integrity, XcodeGen project generation, simulator build, splash in simulator bundle, unit tests, production Release build for iPhone, splash in Release bundle, IPA packaging, IPA upload.

## Active V2 working branch

All rehabilitation work continues from:

`feature/irfaali-v2-rehabilitation-20260916`

Do not work directly on `main`. Do not delete existing backup branches.

## Product rule: zero visible AI branding

Irfaali may use machine learning, computer vision, optical flow, GPU inference or other intelligent techniques internally, but the user-facing product must not market itself as an AI app.

Do not show strings or visual clichés such as:

- AI / A.I. / Artificial Intelligence
- Powered by AI / Designed by AI
- AI Enhanced / AI Analyzer / AI Recommendation
- robot / brain / magic wand / sparkle-as-intelligence branding
- generic AI SaaS visual language

Use human product language instead:

- تحليل الفيديو
- التوصية
- ترميم الفيديو
- رفع الدقة
- استعادة التفاصيل
- معالجة الحركة
- تقليل التشويش

The intelligence should be evident through useful behavior, not labels.

## Target product flow

Import video → analyze source → understand defects → recommend treatment → user confirms or adjusts → process → verify actual output → save/share.

## Current engineering reality at the baseline

### Analyzer

`VideoAnalyzer` currently analyzes metadata only: dimensions, transform, nominal FPS, bitrate estimate, codec, HDR/SDR indicator, duration, audio properties, file size and container. It does **not** currently inspect sampled frame pixels for exposure, clipping, blur, sharpness, noise, compression artifacts, color cast, motion intensity or scene quality.

### Recommended behavior

On import, `StudioViewModel` currently applies `VideoProcessingSettings.recommended(for:)` and `VideoEnhancementSettings.smart(for:)` automatically. This should eventually change so analysis presents a recommendation first and the user explicitly applies it.

`VideoEnhancementSettings.smart(for:)` is currently heuristic, based primarily on bitrate per pixel per frame, source dimensions and HDR metadata. It is not content-aware.

### Image enhancement

Current image enhancement is Core Image based:

- `CINoiseReduction`
- `CIUnsharpMask` for current “detail recovery”
- `CISharpenLuminance`
- `CIColorControls`
- `CIExposureAdjust`

Therefore current “detail recovery” should not be described internally as true learned detail reconstruction. It is a conventional filter path and should be treated honestly.

### Resolution

UI currently offers Source, 1080p, 1440p and 4K. Target size preserves aspect ratio and scales the long edge to the selected target. A selected 4K option must only be considered verified after inspecting the real exported media dimensions.

### Frame rate

UI currently offers Source, 30, 60 and 120 FPS. The project contains an optical-flow-based frame generation path plus verification models/tests. Quality and real device behavior still require explicit validation with source/output frame counts, timestamps and motion artifact review. Do not rely on nominal metadata alone.

### Themes

Settings visually exposes only Dark and Light, but `AppPreferences.Appearance` still contains legacy cases (`system`, `pureBlack`, `dark`, `light`, `pureWhite`). More importantly, several shared visual layers currently force black backgrounds, white foregrounds and dark toolbar schemes. Light mode requires a real end-to-end rebuild rather than a simple toggle.

### Studio UX

Current Studio mixes Output controls, a Recommended action, resolution, frame rate, codec, enhancement presets and six manual sliders in one processing deck. V2 should separate these into a clear hierarchy:

Video preview → Video analysis → Recommendation → Output → Restoration → Advanced → Process.

Use progressive disclosure and keep technical controls subordinate to the primary workflow.

## Typography direction

The desired type identity is the Thmanyah family:

- Thmanyah Sans: primary UI and technical values
- Thmanyah Serif Display: rare editorial/brand moments
- Thmanyah Serif Text: selected long-form copy only

Build a centralized semantic typography layer rather than scattering `Font.custom` calls.

**Important:** the supplied Thmanyah font license permits application embedding/commercial use but restricts redistribution of the font program itself. The repository is public. Do not commit the font binaries to the public repository until licensing/distribution implications are resolved or the project is moved to an appropriate private distribution path.

## Visual direction

The product should feel handcrafted, premium, native to iOS, restrained and editorial. Avoid Material/Android styling, generic AI SaaS dashboards, excessive capsules, cheap glow, random glassmorphism, gamer UI and decorative complexity.

Motion target:

- tap: ~0.98 scale, ~100 ms, easeInOut, no bounce
- section/tab transitions: ~120–180 ms crossfade
- selection: restrained state change + light haptic
- processing: meaningful progress tied to actual processing state

## Quality target

A clean, real 1080p60 export with strong natural detail, stable motion and robust encoding is more important than fake 4K or fake 120 FPS. 4K and 120 FPS remain advanced capabilities only when the actual pipeline can verify them.

Default image policy: preserve source character, repair measurable defects, enhance only when justified. Avoid overexposure, blown highlights, crushed blacks, oversaturation, halo sharpening, plastic denoise and fake HDR.

## Planned implementation phases

1. Brand and UX safety cleanup: remove visible AI branding, correct About copy, persist recovery state.
2. Full UI/UX information architecture and motion redesign, including a genuine Dark/Light system.
3. Local sampled-frame `VideoAnalysisReport` and content analyzer.
4. Recommendation engine that does not auto-apply changes.
5. Quality pipeline and real output verification, including audio integrity.
6. Resolution/4K validation and truthful labels.
7. 60/120 FPS interpolation validation and motion-quality work.
8. Optional GPU backend architecture for workloads that are genuinely too expensive on-device.
9. History, Before/After, errors, recovery, storage and cancellation UX.
10. Full Arabic RTL / English LTR / device / thermal / memory / performance QA, then Release + IPA.

## Release discipline

Every major phase must use isolated, reviewable commits and pass build/tests before the next phase. Do not mark a capability complete because the UI changed; verify the actual generated media.
