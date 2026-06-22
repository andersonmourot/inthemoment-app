import Vapor
import JWT

/// JWT payload issued on login/registration and required by protected routes.
struct UserToken: Content, Authenticatable, JWTPayload {
    /// Subject — the user's id.
    var sub: SubjectClaim
    /// Expiration time.
    var exp: ExpirationClaim
    /// The creator profile this user owns, if any (fans have no creator profile).
    var creatorId: UUID?

    func verify(using algorithm: some JWTAlgorithm) async throws {
        try exp.verifyNotExpired()
    }

    var userId: UUID? { UUID(uuidString: sub.value) }

    /// The user id, required (a valid token always has a subject).
    func requireUserID() throws -> UUID {
        guard let userId else { throw Abort(.unauthorized, reason: "Malformed token.") }
        return userId
    }

    /// The creator id for creator-only actions; 403 for fan accounts.
    func requireCreatorID() throws -> UUID {
        guard let creatorId else { throw Abort(.forbidden, reason: "This action requires a creator account.") }
        return creatorId
    }

    init(userId: UUID, creatorId: UUID?, expiresIn: TimeInterval = 60 * 60 * 24 * 30) {
        self.sub = SubjectClaim(value: userId.uuidString)
        self.exp = ExpirationClaim(value: Date().addingTimeInterval(expiresIn))
        self.creatorId = creatorId
    }
}
