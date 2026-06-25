import Foundation
import Vapor

struct UploadsConfiguration {
    let directory: String
}

struct UploadsConfigurationKey: StorageKey {
    typealias Value = UploadsConfiguration
}

enum UploadStorage {
    static func save(_ file: File, fallbackExtension: String, req: Request) throws -> URL {
        guard let config = req.application.storage[UploadsConfigurationKey.self] else {
            throw Abort(.internalServerError, reason: "Uploads are not configured.")
        }
        let ext = fileExtension(for: file.filename, fallbackExtension: fallbackExtension)
        let filename = "\(UUID().uuidString).\(ext)"
        let destination = URL(fileURLWithPath: config.directory, isDirectory: true)
            .appendingPathComponent(filename)

        var buffer = file.data
        guard let data = buffer.readData(length: buffer.readableBytes), !data.isEmpty else {
            throw Abort(.badRequest, reason: "Upload file is empty.")
        }
        try data.write(to: destination)
        return try publicURL(filename: filename, req: req)
    }

    static func publicURL(filename: String, req: Request) throws -> URL {
        if let base = Environment.get("PUBLIC_BASE_URL"),
           let url = URL(string: base)?.appendingPathComponent("uploads").appendingPathComponent(filename) {
            return url
        }
        guard let host = req.headers.first(name: "Host") else {
            throw Abort(.internalServerError, reason: "Could not build upload URL.")
        }
        let proto = req.headers.first(name: "X-Forwarded-Proto") ?? publicScheme(for: host)
        guard let url = URL(string: "\(proto)://\(host)/uploads/\(filename)") else {
            throw Abort(.internalServerError, reason: "Could not build upload URL.")
        }
        return url
    }

    private static func publicScheme(for host: String) -> String {
        if host.hasPrefix("localhost") || host.hasPrefix("127.0.0.1") || host.hasPrefix("0.0.0.0") {
            return "http"
        }
        return "https"
    }

    private static func fileExtension(for filename: String, fallbackExtension: String) -> String {
        let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
        let allowed = Set(["jpg", "jpeg", "png", "heic", "webp", "gif", "mp4", "mov", "m4v"])
        if allowed.contains(ext) { return ext }
        return fallbackExtension
    }
}

struct UploadController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("uploads", ":filename", use: show)
    }

    func show(req: Request) async throws -> Response {
        guard let filename = req.parameters.get("filename"),
              filename == URL(fileURLWithPath: filename).lastPathComponent,
              let config = req.application.storage[UploadsConfigurationKey.self] else {
            throw Abort(.notFound)
        }

        let fileURL = URL(fileURLWithPath: config.directory, isDirectory: true)
            .appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw Abort(.notFound)
        }
        return try await req.fileio.asyncStreamFile(at: fileURL.path)
    }
}
