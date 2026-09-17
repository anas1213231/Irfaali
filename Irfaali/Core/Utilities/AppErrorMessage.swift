import Foundation

enum AppErrorMessage {
    static func describe(_ error: Error, isArabic: Bool) -> String {
        if isArabic { return error.localizedDescription }
        // Service errors carry Arabic descriptions; present an English action
        // rather than mixing two languages in the editor.
        switch error {
        case let error as StudioViewModel.ProcessingError:
            switch error {
            case .outputMismatch:
                return "The exported video did not match your settings. Try a lower resolution or keep the source frame rate."
            case .frameGenerationDeviceBlocked:
                return "Frame generation is unavailable with the current device conditions or resolution. Let the device cool down or lower the resolution."
            case .frameGenerationVerificationFailed, .frameGenerationVerificationUnavailable:
                return "The generated frames could not be verified. The incomplete output was removed. Try keeping the source frame rate."
            }
        case is FrameGenerationService.GenerationError:
            return "Motion processing could not finish. Try a shorter video or lower resolution."
        case let error as OpticalFlowService.FlowError:
            switch error {
            case .thermalCritical:
                return "Frame generation stopped because the device reached a critical thermal state. Let the device cool down and try again."
            default:
                return "Motion analysis could not finish. Try a shorter video or lower resolution."
            }
        case is VideoEnhancementService.EnhancementError:
            return "Image adjustment could not finish. Try another video or reduce the adjustment settings."
        case is VideoExportService.ExportError:
            return "Export could not finish with these settings. Try H.264 or a lower resolution."
        default:
            let description = error.localizedDescription
            if description.unicodeScalars.contains(where: { (0x0600...0x06FF).contains(Int($0.value)) }) {
                return "The operation could not finish. Check access to the video, available storage, and Photos permission."
            }
            return description
        }
    }
}
