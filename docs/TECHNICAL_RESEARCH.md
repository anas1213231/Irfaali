# ارفعلي — Technical research baseline

Research date: 2026-09-12.

## Official / documented

- TikTok Content Posting API Media Transfer Guide currently documents MP4 (recommended), WebM and MOV; H.264 (recommended), H.265, VP8 and VP9; **23–60 FPS**; **360–4096 px** on both width and height; and up to 4 GB. Source: https://developers.tiktok.com/doc/content-posting-api-media-transfer-guide
- Apple documents `AVAssetExportPresetHighestQuality` as H.264 + AAC and `AVAssetExportPresetHEVCHighestQuality` as HEVC + AAC. Source: https://developer.apple.com/documentation/avfoundation/export-presets
- Apple VideoToolbox `VTCompressionSession` is the lower-level path for explicit frame-by-frame hardware-capable encoding work. Source: https://developer.apple.com/documentation/videotoolbox/vtcompressionsession
- Apple’s current design direction uses Liquid Glass for the functional control/navigation layer while keeping content dominant. Standard SwiftUI controls adopt the current system treatment when built with the current SDK. Source: https://developer.apple.com/documentation/technologyoverviews/liquid-glass
- 2026 Apple Design Award examples emphasize focused content, coherent custom animation, strong hierarchy and system-native interaction rather than indiscriminate decorative glass. Source: https://developer.apple.com/design/awards/

## Product rules derived from those sources

1. Never market a TikTok posting workflow as 120 FPS when the official posting API range is capped at 60 FPS.
2. Preserve source cadence where possible. When capping a source above 60 FPS, label the result **Retimed 60 FPS**, never Native 60 FPS.
3. A future 120 FPS experiment must explicitly say `Generated 120 FPS — Frame Duplication`, `Generated 120 FPS — Interpolated`, or `Container Timing Experiment` as appropriate.
4. Platform-specific claims stay separate from empirically observed behavior because TikTok can re-encode uploaded video.
5. UI hierarchy is content-first: restrained glass surfaces, strong spacing, legible metrics, motion tied to state changes.
