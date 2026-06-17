import Foundation
import InTheMomentCore

/// Manages sign-in state: talks to the backend's `/auth` endpoints via
/// ``AuthClient`` and persists the bearer token through ``TokenHolder``.
@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var signedInCreator: Creator?
    @Published var isWorking = false
    @Published var errorMessage: String?

    var isAuthenticated: Bool { signedInCreator != nil }

    private let client: AuthClient

    init(baseURL: URL = AppConfig.apiBaseURL) {
        self.client = AuthClient(baseURL: baseURL)
    }

    /// Restores a session on launch if a token is stored. Returns the creator
    /// when the token is still valid; clears it otherwise.
    func restore() async -> Creator? {
        guard let token = TokenHolder.shared.token else { return nil }
        do {
            let creator = try await client.me(token: token)
            signedInCreator = creator
            return creator
        } catch {
            TokenHolder.shared.set(nil)
            return nil
        }
    }

    func register(email: String, password: String, displayName: String, handle: String) async -> Creator? {
        await run {
            try await self.client.register(email: email, password: password, displayName: displayName, handle: handle)
        }
    }

    func login(email: String, password: String) async -> Creator? {
        await run {
            try await self.client.login(email: email, password: password)
        }
    }

    func logout() {
        TokenHolder.shared.set(nil)
        signedInCreator = nil
    }

    private func run(_ action: @escaping () async throws -> AuthSession) async -> Creator? {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let session = try await action()
            TokenHolder.shared.set(session.token)
            signedInCreator = session.creator
            return session.creator
        } catch let error as AuthError {
            errorMessage = error.message
            return nil
        } catch {
            errorMessage = "Something went wrong. Please try again."
            return nil
        }
    }
}
