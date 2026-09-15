# Release acceptance checklist

## Automated coverage

The iOS workflow runs the media pipeline on a simulator before packaging the
device Release build. It checks:

- source analysis for dimensions, frame rate, codec, duration and audio;
- export and enhancement outputs that decode successfully;
- output dimensions, frame rate, duration and audio timing;
- monotonically increasing video presentation timestamps;
- cancellation cleanup and persistent history records; and
- portrait output geometry, including a real 4K source fixture.

These checks are deterministic and use generated fixtures only. They do not
replace a final physical-device pass with the owner's signing certificate.

## Release artifact

After the workflow is green, it builds the standard `Release` configuration for
the iPhone device SDK and uploads:

- `Irfaali-1.1.ipa`; and
- `BUILD-INFO.txt` with the source SHA and IPA SHA-256 checksum.

The IPA is intentionally unsigned in the public CI workflow. Apply the owner's
Apple certificate and provisioning profile with the signing workflow or the
eSign tool before installing it on an iPhone.

## Physical-device acceptance

Before public distribution, install the signed IPA and run representative
clips through import, analysis, export, enhancement, save, share and history.
Check H.264 and HEVC, portrait and landscape sources, audio synchronization,
background/foreground transitions, cancellation and the largest source files
you intend to support. Record the device model, iOS version, source SHA and
observed output for each case.

The release surface only presents resolutions and frame rates that the source
can actually provide. A larger output is never implied to restore detail, and
frame synthesis is not presented as a finished feature.
