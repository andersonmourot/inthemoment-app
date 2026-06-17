import Foundation
import Photos
import InTheMomentCore

/// Downloads a ``MediaItem``'s asset and saves it to the user's photo library so they
/// can use it however they like (the core promise of In The Moment).
enum MediaDownloader {
    enum DownloadError: LocalizedError {
        case notDownloadable
        case permissionDenied
        case badResponse

        var errorDescription: String? {
            switch self {
            case .notDownloadable: return "The creator disabled downloads for this item."
            case .permissionDenied: return "Allow photo library access in Settings to save media."
            case .badResponse: return "Couldn't download this item. Try again."
            }
        }
    }

    /// Downloads `item` and writes it to the photo library, requesting permission if needed.
    static func saveToPhotoLibrary(_ item: MediaItem) async throws {
        guard item.isDownloadable else { throw DownloadError.notDownloadable }
        try await requestAddPermission()

        let (data, response) = try await URLSession.shared.data(from: item.url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw DownloadError.badResponse
        }

        switch item.kind {
        case .photo:
            try await performChange { request in
                request.addResource(with: .photo, data: data, options: nil)
            }
        case .video:
            // PHPhotoLibrary requires a file URL for video resources.
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(item.url.pathExtension.isEmpty ? "mp4" : item.url.pathExtension)
            try data.write(to: tmp)
            defer { try? FileManager.default.removeItem(at: tmp) }
            try await performChange { request in
                request.addResource(with: .video, fileURL: tmp, options: nil)
            }
        }
    }

    private static func requestAddPermission() async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            return
        case .notDetermined:
            let granted = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard granted == .authorized || granted == .limited else {
                throw DownloadError.permissionDenied
            }
        default:
            throw DownloadError.permissionDenied
        }
    }

    private static func performChange(_ body: @escaping (PHAssetCreationRequest) -> Void) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            body(request)
        }
    }
}
