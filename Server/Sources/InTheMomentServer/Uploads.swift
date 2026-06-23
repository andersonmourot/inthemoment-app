import Foundation
import Vapor

struct UploadsConfiguration {
    let directory: String
}

struct UploadsConfigurationKey: StorageKey {
    typealias Value = UploadsConfiguration
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
