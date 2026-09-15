# ارفعلي (Irfaali)

Production-oriented iPhone video analysis and export engine built with SwiftUI, AVFoundation, SwiftData and Swift Concurrency.

## Owner / Developer

Owner / Developer: **@ucorc**

Telegram: https://t.me/ucorc

Copyright: © 2026 @ucorc. All Rights Reserved.

## Current executable scope

- Import video from Photos or Files.
- Real AVFoundation analysis: dimensions, source FPS, codec, estimated bitrate, duration, size, audio information and track timing scale.
- TikTok posting compatibility checks based on the currently documented 23–60 FPS and 360–4096 px restrictions.
- Real exports: H.264 high-quality, HEVC highest-quality, or original file copy.
- Sources above 60 FPS are explicitly capped/retimed for the TikTok preset and labeled **Retimed 60 FPS** — never native 60/120.
- Real export progress from `AVAssetExportSession.progress`.
- Every successful export is re-analyzed with AVFoundation and shown in a verified before/after technical comparison.
- Save exported video to Photos using real add-only Photo Library authorization, or share with the iOS Share Sheet.
- Persistent export history with SwiftData.
- Read-only output details with explicit source/output timing terminology.
- Video exports remain clean: no developer watermark, logo overlay, intro, or outro is injected into user media.
- The current product has no StoreKit subscription, paywall, credits/coins, paid codec/FPS tier, export limit, trial gate, or forced ads.
- The release interface exposes only source-supported frame rates and resolutions; unsupported synthesis is not advertised or enabled.

## Generate the Xcode project

```bash
brew install xcodegen
bash scripts/prepare_app_icon.sh
xcodegen generate
open Irfaali.xcodeproj
```

Minimum target: iOS 17. CI builds and tests with Xcode 26.6 on GitHub-hosted macOS 26.

## Signing / IPA

The `Signed IPA` GitHub Actions workflow expects these repository secrets:

- `IOS_CERTIFICATE_P12_BASE64`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_EXPORT_METHOD` (`development`, `ad-hoc`, `app-store-connect`, or the method matching the supplied profile)
- `APPLE_TEAM_ID`
- `APP_BUNDLE_ID`

The workflow intentionally fails early if any signing input is missing. A successful run archives, exports the signed IPA, uploads it as an Actions artifact, and publishes it in a GitHub Release. It does not fabricate a successful signing state.

## Research and sample baseline

See `docs/TECHNICAL_RESEARCH.md` and `docs/SAMPLE_VIDEO_BASELINE.md`.
