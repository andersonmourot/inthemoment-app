import Foundation
import UniformTypeIdentifiers
import InTheMomentCore

struct MediaUploadService {
    private let baseURL: URL
    private let tokenProvider: () -> String?
    private let decoder: JSONDecoder

    init(baseURL: URL = AppConfig.apiBaseURL, tokenProvider: @escaping () -> String? = { TokenHolder.shared.token }) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func upload(
        data: Data,
        fileExtension: String,
        kind: MediaKind,
        to eventID: UUID
    ) async throws -> MediaItem {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appendingPathComponent("events/\(eventID.uuidString)/uploads"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = multipartBody(
            boundary: boundary,
            data: data,
            fileExtension: fileExtension,
            kind: kind
        )

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw UploadError.failed
        }
        return try decoder.decode(MediaItem.self, from: responseData)
    }

    private func multipartBody(
        boundary: String,
        data: Data,
        fileExtension: String,
        kind: MediaKind
    ) -> Data {
        var body = Data()
        let ext = fileExtension.isEmpty ? defaultFileExtension(for: kind) : fileExtension

        body.appendFormField(name: "kind", value: kind.rawValue, boundary: boundary)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"upload.\(ext)\"\r\n")
        body.append("Content-Type: \(mimeType(for: ext, kind: kind))\r\n\r\n")
        body.append(data)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")
        return body
    }

    private func defaultFileExtension(for kind: MediaKind) -> String {
        kind == .video ? "mp4" : "jpg"
    }

    private func mimeType(for fileExtension: String, kind: MediaKind) -> String {
        UTType(filenameExtension: fileExtension)?.preferredMIMEType
            ?? (kind == .video ? "video/mp4" : "image/jpeg")
    }
}

private enum UploadError: Error {
    case failed
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }

    mutating func appendFormField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }
}
