import Foundation
import Photos

struct PhotoLibrarySaver: Sendable {
    enum SaveError: LocalizedError {
        case permissionDenied
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "لا توجد صلاحية لإضافة الفيديو إلى مكتبة الصور."
            case .failed(let message):
                return "تعذر حفظ الفيديو: \(message)"
            }
        }
    }

    func saveVideo(at url: URL) async throws {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let status: PHAuthorizationStatus
        if current == .notDetermined {
            status = await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { value in
                    continuation.resume(returning: value)
                }
            }
        } else {
            status = current
        }

        guard status == .authorized || status == .limited else {
            throw SaveError.permissionDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: SaveError.failed(error?.localizedDescription ?? "Unknown error"))
                }
            }
        }
    }
}
