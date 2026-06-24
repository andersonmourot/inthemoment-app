import Foundation
import PhotosUI
import UniformTypeIdentifiers
import InTheMomentCore

enum EventMediaImporter {
    static func importItems(_ items: [PhotosPickerItem], to eventId: UUID, model: AppModel) async throws {
        for item in items {
            guard let data = try await item.loadTransferable(type: Data.self) else { continue }
            let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
            let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? (isVideo ? "mp4" : "jpg")
            let kind: MediaKind = isVideo ? .video : .photo
            let thumbnailData = isVideo ? try? VideoThumbnailGenerator.jpegData(for: data, fileExtension: ext) : nil
            do {
                try await model.uploadMedia(
                    data: data,
                    fileExtension: ext,
                    kind: kind,
                    thumbnailData: thumbnailData,
                    to: eventId
                )
                continue
            } catch {
                // If the deployed API does not support uploads yet, keep local media working.
            }

            let url = try MediaStorage.store(data: data, fileExtension: ext)
            let thumbnailURL = try thumbnailData.map { try MediaStorage.store(data: $0, fileExtension: "jpg") }
            let media = MediaItem(
                eventId: eventId,
                kind: kind,
                url: url,
                thumbnailURL: thumbnailURL ?? (isVideo ? nil : url)
            )
            await model.addMedia(media, to: eventId)
        }
    }
}
