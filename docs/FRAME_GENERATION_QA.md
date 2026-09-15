# ارفعلي — Frame Generation QA Gate

The 2× frame-generation engine is implemented as a real motion-aware pipeline, but the public Studio control must stay locked until device-level quality checks pass.

## What the engine must prove before the lock is removed

- 30 → 60 FPS output contains newly synthesized midpoint frames, never duplicated motion frames.
- 60 → 120 FPS output contains newly synthesized midpoint frames, never duplicated motion frames.
- Hard scene cuts never run through optical-flow interpolation; cut-safe cadence samples are counted separately from synthesized frames.
- Final analyzer reports the requested output cadence within normal encoder tolerance.
- Audio stays synchronized from start to finish.
- Portrait, landscape and rotated source tracks keep their expected orientation.
- H.264 and HEVC outputs both decode and seek correctly.
- 1080p jobs complete without runaway memory growth.
- 2K/4K jobs fail gracefully if device resources are insufficient.
- Cancellation removes temporary files and does not leave broken library records.
- Cancellation is verified independently during base export, frame generation, enhancement and audio mux.
- App background / foreground transitions do not corrupt an active export.
- Thermal / Low Power Mode readiness is validated on a physical iPhone; simulator state is never treated as proof of device readiness.

## Visual stress cases

Test every release candidate with:

1. Fast camera pans.
2. A moving subject crossing a static background.
3. Thin lines, subtitles and UI screen recordings.
4. Repeated patterns such as fences, windows and road markings.
5. Occlusion: one object passes in front of another; inspect for double edges and transparent-looking ghosts.
6. Hard scene cuts, flash frames and abrupt exposure changes; inspect for cross-shot blending.
7. Low-light / noisy footage.
8. Highly compressed social-media footage.
9. Gameplay with HUD elements.
10. Slow-motion footage that already contains 60/120 FPS source cadence.
11. Fine hair, fingers, spokes and other thin fast-moving geometry.
12. Camera motion plus independently moving foreground objects.

## Cancellation / recovery stress cases

For every processing stage:

1. Cancel immediately after the stage starts.
2. Cancel around the middle of the stage.
3. Cancel near completion.
4. Confirm the UI returns to an idle/recoverable state.
5. Confirm no partial export is shown in `فيديوهاتي`.
6. Confirm partial files and silent frame-generation intermediates are removed.
7. Start a new job immediately after cancellation and confirm it completes normally.

## Acceptance rule

A frame-generated result may be exposed to normal users only when:

- the output file passes technical verification,
- no duplicated-frame shortcut is used for ordinary motion,
- scene-cut fallback cadence is explicitly accounted for and not called AI-generated,
- visual artifacts remain acceptable across the stress set,
- audio sync is stable,
- cancellation/recovery is clean,
- and the app remains responsive and recoverable on supported iPhones.

Until then, the engine can be exercised through the internal processing path while the public Studio button remains gated.
