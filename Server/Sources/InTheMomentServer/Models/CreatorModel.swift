import Fluent
import Foundation
import InTheMomentCore

final class CreatorModel: Model, @unchecked Sendable {
    static let schema = "creators"

    @ID(custom: "id", generatedBy: .user) var id: UUID?
    @Field(key: "display_name") var displayName: String
    @Field(key: "handle") var handle: String
    @OptionalField(key: "bio") var bio: String?
    @OptionalField(key: "avatar_url") var avatarURL: String?
    @Field(key: "is_verified") var isVerified: Bool
    @Field(key: "joined_at") var joinedAt: Date

    init() {}

    init(from creator: Creator) {
        self.id = creator.id
        self.displayName = creator.displayName
        self.handle = creator.handle
        self.bio = creator.bio
        self.avatarURL = creator.avatarURL?.absoluteString
        self.isVerified = creator.isVerified
        self.joinedAt = creator.joinedAt
    }

    func apply(_ creator: Creator) {
        self.displayName = creator.displayName
        self.handle = creator.handle
        self.bio = creator.bio
        self.avatarURL = creator.avatarURL?.absoluteString
        self.isVerified = creator.isVerified
        self.joinedAt = creator.joinedAt
    }

    func toDTO() -> Creator {
        Creator(
            id: id ?? UUID(),
            displayName: displayName,
            handle: handle,
            bio: bio,
            avatarURL: avatarURL.flatMap(URL.init(string:)),
            isVerified: isVerified,
            joinedAt: joinedAt
        )
    }
}

struct CreateCreator: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(CreatorModel.schema)
            .field("id", .uuid, .identifier(auto: false))
            .field("display_name", .string, .required)
            .field("handle", .string, .required)
            .unique(on: "handle")
            .field("bio", .string)
            .field("avatar_url", .string)
            .field("is_verified", .bool, .required)
            .field("joined_at", .datetime, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(CreatorModel.schema).delete()
    }
}
