# Device QA candidate

## Automated checks

The iOS CI workflow now runs real-media integration tests in addition to model tests:

- Original-file export is byte-for-byte identical.
- A rotated 60 FPS source exports at 30 FPS with the expected displayed dimensions.
- H.264 output decodes all frames with increasing presentation timestamps.
- Audio/video track start and end times remain within the test tolerances.
- The enhancement service produces a decodable output with audio.
- Cancellation before export entry returns cancellation and preserves the source.

Fixtures are generated locally by the test suite: a one-second 320×180 video and a 48 kHz tone. No user videos, network fixtures, or signing credentials are required.

Track timing checks do **not** prove perceptual lip sync. Small synthetic fixtures do **not** prove 1080p/4K memory behavior, HEVC hardware behavior, visual quality, or mid-stage cancellation.

## Candidate artifact

After successful tests, CI builds the Release configuration for the iPhone device SDK and uploads:

- `Irfaali-device-qa.ipa`
- `BUILD-INFO.txt` containing the source SHA and IPA SHA-256 checksum

Download the `Irfaali-device-qa-<commit>` artifact from the successful Actions run. It is an unsigned device build and requires a compatible Apple certificate/provisioning profile before installation. The artifact expires after 14 days. CI does not publish or replace a GitHub Release.

## Remaining acceptance work

1. Sign the candidate using the owner's Apple signing setup and install on a physical iPhone.
2. Exercise import → analysis → export → enhancement → save/share/history with representative real clips.
3. Test HEVC, 1080p/4K, audio synchronization, background/foreground transitions, and cancellation during every processing stage.
4. Run the optical-flow stress set in `FRAME_GENERATION_QA.md` through the internal processing path.
5. Record device model, iOS version, source SHA, sample properties, outcome, and observed artifacts for each case.
6. Only remove the public frame-generation gate after the device acceptance requirements pass.

The public frame-generation control remains gated. A green simulator run is not evidence of physical-device optical-flow quality.

## Version 1.1 candidate

The DeviceQA configuration is optimized as Release and defines IRFAALI_DEVICE_QA.
Only this build exposes an explicit, per-import experimental generation toggle.
Normal Release builds retain the public gate. This does not mark physical-device
acceptance as passed. Test 30→60 and 60→120 with this toggle; other ratios remain
unavailable. The output must match requested dimensions/FPS/duration/audio, and
frame-generated files are read back to check the encoded sample count.

A 4K selection means spatial resizing, not recovery of missing source detail.
The integration suite exports and decodes an actual portrait 2160×3840 file.
The 1.1 candidate also includes a shorter launch, uncropped official-logo layout,
a larger video picker, visual theme choices, and removal of access/free banners.
