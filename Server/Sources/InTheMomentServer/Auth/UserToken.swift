import Vapor
import JWT

/// JWT payload issued on login/registration and required by protected routes.
struct UserToken: Content, Authenticatable, JWTPayload {
    /// Subject — the user's id.
    var sub: SubjectClaim
    /// Expiration time.
    var exp: ExpirationClaim
    /// The creator profile this user owns (kept in the token to avoid an extra lookup).
    var creatorId: UUID

    func verify(using algorithm: some JWTAlgorithm) async throws {
        try exp.verifyNotExpired()
    }

    var userId: UUID? { UUID(uuidString: sub.value) }

    init(userId: UUID, creatorId: UUID, expiresIn: TimeInterval = 60 * 60 * 24 * 30) {
        self.sub = SubjectClaim(value: userId.uuidString)
        self.exp = ExpirationClaim(value: Date().addingTimeInterval(expiresIn))
        self.creatorId = creatorId
    }
}
