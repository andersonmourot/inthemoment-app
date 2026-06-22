import Foundation
import InTheMomentCore

/// Manages sign-in state: talks to the backend's `/auth` endpoints via
/// ``AuthClient`` and persists the bearer token through ``TokenHolder``.
///
/// An account is either a *creator* (has a ``Creator`` profile and can post events)
/// or a *fan* (email + password only; favorites/follows sync to the account).
@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var account: Account?
    @Published var isWorking = false
    @Published var errorMessage: String?

    var isAuthenticated: Bool { account != nil }
    /// The signed-in creator profile, or `nil` for fan / anonymous sessions.
    var signedInCreator: Creator? { account?.creator }

    private let client: AuthClient

    init(baseURL: URL = AppConfig.apiBaseURL) {
        self.client = AuthClient(baseURL: baseURL)
    }

    /// Restores a session on launch if a token is stored. Returns the account
    /// when the token is still valid; clears it otherwise.
    func restore() async -> Account? {
        guard let token = TokenHolder.shared.token else { return nil }
        do {
            let account = try await client.me(token: token)
            self.account = account
            return account
        } catch {
            TokenHolder.shared.set(nil)
            return nil
        }
    }

    func register(email: String, password: String, displayName: String, handle: String) async -> Account? {
        await run(email: email) {
            try await self.client.register(email: email, password: password, displayName: displayName, handle: handle)
        }
    }

    /// Registers a fan account (email + password only).
    func registerFan(email: String, password: String) async -> Account? {
        await run(email: email) {
            try await self.client.registerFan(email: email, password: password)
        }
    }

    func login(email: String, password: String) async -> Account? {
        await run(email: email) {
            try await self.client.login(email: email, password: password)
        }
    }

    func logout() {
        TokenHolder.shared.set(nil)
        account = nil
    }

    private func run(email: String, _ action: @escaping () async throws -> AuthSession) async -> Account? {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let session = try await action()
            TokenHolder.shared.set(session.token)
            let account = Account(email: email, creator: session.creator)
            self.account = account
            return account
        } catch let error as AuthError {
            errorMessage = error.message
            return nil
        } catch {
            errorMessage = "Something went wrong. Please try again."
            return nil
        }
    }
}
