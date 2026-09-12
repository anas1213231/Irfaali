# ارفعلي — Frame Generation QA Gate

The 2× frame-generation engine is implemented as a real motion-aware pipeline, but the public Studio control must stay locked until device-level quality checks pass.

## What the engine must prove before the lock is removed

- 30 → 60 FPS output contains newly synthesized midpoint frames, never duplicated frames.
- 60 → 120 FPS output contains newly synthesized midpoint frames, never duplicated frames.
- Final analyzer reports the requested output cadence within normal encoder tolerance.
- Audio stays synchronized from start to finish.
- Portrait, landscape and rotated source tracks keep their expected orientation.
- H.264 and HEVC outputs both decode and seek correctly.
- 1080p jobs complete without runaway memory growth.
- 2K/4K jobs fail gracefully if device resources are insufficient.
- Cancellation removes temporary files and does not leave broken library records.
- App background / foreground transitions do not corrupt an active export.

## Visual stress cases

Test every release candidate with:

1. Fast camera pans.
2. A moving subject crossing a static background.
3. Thin lines, text and UI screen recordings.
4. Repeated patterns such as fences, windows and road markings.
5. Occlusion: one object passes in front of another.
6. Scene cuts and flashes.
7. Low-light / noisy footage.
8. Highly compressed social-media footage.
9. Gameplay with HUD elements.
10. Slow-motion footage that already contains 60/120 FPS source cadence.

## Acceptance rule

A frame-generated result may be exposed to normal users only when:

- the output file passes technical verification,
- no duplicated-frame shortcut is used,
- visual artifacts remain acceptable across the stress set,
- audio sync is stable,
- and the app remains responsive and recoverable on supported iPhones.

Until then, the engine can be exercised through the internal processing path while the public Studio button remains gated.
