import Fluent
import Foundation
import Vapor

/// An authenticated account. Each user owns exactly one ``CreatorModel`` profile.
final class UserModel: Model, @unchecked Sendable {
    static let schema = "users"

    @ID(custom: "id", generatedBy: .user) var id: UUID?
    @Field(key: "email") var email: String
    @Field(key: "password_hash") var passwordHash: String
    @Field(key: "creator_id") var creatorId: UUID
    @Field(key: "created_at") var createdAt: Date

    init() {}

    init(id: UUID = UUID(), email: String, passwordHash: String, creatorId: UUID, createdAt: Date = Date()) {
        self.id = id
        self.email = email
        self.passwordHash = passwordHash
        self.creatorId = creatorId
        self.createdAt = createdAt
    }
}

struct CreateUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(UserModel.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("email", .string, .required)
            .unique(on: "email")
            .field("password_hash", .string, .required)
            .field("creator_id", .uuid, .required, .references(CreatorModel.schema, "id", onDelete: .cascade))
            .field("created_at", .datetime, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(UserModel.schema).delete()
    }
}
