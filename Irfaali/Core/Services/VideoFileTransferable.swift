import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct VideoFileTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { value in
            SentTransferredFile(value.url)
        } importing: { received in
            let extensionName = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("irfaali-import-\(UUID().uuidString).\(extensionName)")
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: received.file, to: destination)
            return VideoFileTransferable(url: destination)
        }
    }
}
