@preconcurrency import AVFoundation
import CoreImage

enum VideoImageFilters {
    static func composition(asset: AVAsset, settings: VideoEnhancementSettings) -> AVVideoComposition {
        let normalized = settings.normalized()
        return AVVideoComposition(
            asset: asset,
            applyingCIFiltersWithHandler: { request in
                autoreleasepool {
                    let sourceExtent = request.sourceImage.extent
                    var image = request.sourceImage.clampedToExtent()

                    if normalized.denoise > 0.001 {
                        image = image.applyingFilter(
                            "CINoiseReduction",
                            parameters: [
                                "inputNoiseLevel": 0.006 + normalized.denoise * 0.055,
                                "inputSharpness": 0.34 + normalized.detailRecovery * 0.24
                            ]
                        )
                    }

                    if normalized.detailRecovery > 0.001 {
                        image = image.applyingFilter(
                            "CIUnsharpMask",
                            parameters: [
                                "inputRadius": 1.25 + normalized.detailRecovery * 2.75,
                                "inputIntensity": 0.08 + normalized.detailRecovery * 0.72
                            ]
                        )
                    }

                    if normalized.sharpening > 0.001 {
                        image = image.applyingFilter(
                            "CISharpenLuminance",
                            parameters: [
                                "inputSharpness": 0.05 + normalized.sharpening * 0.82
                            ]
                        )
                    }

                    if normalized.colorBoost > 0.001 {
                        image = image.applyingFilter(
                            "CIColorControls",
                            parameters: [
                                "inputSaturation": 1.0 + normalized.colorBoost * 0.18,
                                "inputContrast": 1.0 + normalized.colorBoost * 0.07,
                                "inputBrightness": normalized.colorBoost * 0.008
                            ]
                        )
                    }

                    if abs(normalized.exposure) > 0.001 {
                        image = image.applyingFilter("CIExposureAdjust", parameters: ["inputEV": normalized.exposure * 2])
                    }
                    if abs(normalized.contrast) > 0.001 {
                        image = image.applyingFilter("CIColorControls", parameters: ["inputContrast": 1 + normalized.contrast * 0.5])
                    }
                    request.finish(with: image.cropped(to: sourceExtent), context: nil)
                }
            }
        )

    }
}
