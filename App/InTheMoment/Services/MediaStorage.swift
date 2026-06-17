import Foundation

/// Persists media picked by a creator into the app's Documents directory and
/// returns a stable file URL that the rest of the app can display and download.
///
/// This stands in for uploading to a real media backend; the returned URL is what
/// a server would otherwise hand back.
enum MediaStorage {
    private static var mediaDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("media", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func store(data: Data, fileExtension: String) throws -> URL {
        let url = mediaDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension.isEmpty ? "dat" : fileExtension)
        try data.write(to: url)
        return url
    }
}
