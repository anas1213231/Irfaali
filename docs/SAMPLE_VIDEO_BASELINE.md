# Uploaded sample — initial technical baseline

Analyzed locally with `ffprobe` on 2026-09-12. This is a test baseline, not app-generated mock data.

- Container: MP4 / ISO Base Media File Format
- Duration: 63.533333 s
- File size: 30,275,931 bytes (~30.28 MB decimal)
- Overall bitrate: 3,812,289 bit/s
- Video: H.264 High Profile, Level 3.1
- Dimensions: 512 × 682 (portrait)
- Pixel format: yuv420p
- Color: BT.709 primaries / transfer / matrix (SDR)
- Native source cadence: 30/1 fps
- Video frames reported by ffprobe: 1,906
- Video bitrate: 3,776,291 bit/s
- Video time base: 1/600
- Audio: HE-AAC, stereo, 44.1 kHz
- Audio bitrate: 32,083 bit/s

Conclusion: this sample is **native 30 FPS**, not 60 or 120 FPS. The initial TikTok preset should preserve 30 FPS rather than manufacture a higher number.
