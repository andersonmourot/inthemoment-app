import Foundation
import InTheMomentCore

struct ReportService {
    private let baseURL: URL
    private let tokenProvider: () -> String?
    private let encoder: JSONEncoder

    init(baseURL: URL = AppConfig.apiBaseURL, tokenProvider: @escaping () -> String? = { TokenHolder.shared.token }) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.encoder = JSONEncoder()
    }

    func submit(_ report: ReportRequest) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("reports"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try encoder.encode(report)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ReportError.failed
        }
    }
}

private enum ReportError: LocalizedError {
    case failed

    var errorDescription: String? {
        "Couldn't submit this report. Please try again."
    }
}
