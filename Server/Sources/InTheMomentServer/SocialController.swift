import Vapor
import Fluent
import InTheMomentCore

/// Comments and likes on events. Reads are public (likes optionally use the
/// token to report the viewer's like state); writes require authentication.
/// Comments may be deleted by their author or the event's owning creator.
struct SocialController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let events = routes.grouped("events")

        // Public reads.
        events.get(":id", "comments", use: listComments)
        // Optional auth: anonymous callers get likedByViewer == false.
        events.grouped(UserToken.authenticator()).get(":id", "likes", use: likeSummary)

        // Authenticated writes.
        let protected = events.grouped(UserToken.authenticator(), UserToken.guardMiddleware())
        protected.post(":id", "comments", use: addComment)
        protected.delete(":id", "comments", ":commentId", use: deleteComment)
        protected.post(":id", "like", use: like)
        protected.delete(":id", "like", use: unlike)
    }

    struct CommentBody: Content { let body: String }

    func listComments(req: Request) async throws -> [Comment] {
        let eventId = try id(req)
        let rows = try await CommentModel.query(on: req.db)
            .filter(\.$eventId == eventId)
            .sort(\.$createdAt, .ascending)
            .all()
        return rows.map { $0.toDTO() }
    }

    func addComment(req: Request) async throws -> Comment {
        let token = try req.auth.require(UserToken.self)
        let userId = try token.requireUserID()
        let eventId = try id(req)
        guard try await EventModel.find(eventId, on: req.db) != nil else { throw Abort(.notFound) }

        let text = try req.content.decode(CommentBody.self).body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Comment.isValidBody(text) else {
            throw Abort(.unprocessableEntity, reason: "Comment must be 1–2000 characters.")
        }

        let name = try await Self.authorName(for: userId, on: req.db)
        let model = CommentModel(eventId: eventId, userId: userId, authorName: name, body: text)
        try await model.create(on: req.db)
        return model.toDTO()
    }

    func deleteComment(req: Request) async throws -> HTTPStatus {
        let token = try req.auth.require(UserToken.self)
        let userId = try token.requireUserID()
        let eventId = try id(req)
        guard let commentId = req.parameters.get("commentId", as: UUID.self) else { throw Abort(.badRequest) }
        guard let comment = try await CommentModel.find(commentId, on: req.db), comment.eventId == eventId else {
            throw Abort(.notFound)
        }

        let isAuthor = comment.userId == userId
        let isEventOwner: Bool
        if let creatorId = token.creatorId, let event = try await EventModel.find(eventId, on: req.db) {
            isEventOwner = event.creatorId == creatorId
        } else {
            isEventOwner = false
        }
        guard isAuthor || isEventOwner else { throw Abort(.forbidden) }

        try await comment.delete(on: req.db)
        return .noContent
    }

    func likeSummary(req: Request) async throws -> LikeSummary {
        let eventId = try id(req)
        guard try await EventModel.find(eventId, on: req.db) != nil else { throw Abort(.notFound) }
        let viewerId = req.auth.get(UserToken.self)?.userId
        return try await Self.summary(eventId: eventId, viewerId: viewerId, on: req.db)
    }

    func like(req: Request) async throws -> LikeSummary {
        let token = try req.auth.require(UserToken.self)
        let userId = try token.requireUserID()
        let eventId = try id(req)
        guard try await EventModel.find(eventId, on: req.db) != nil else { throw Abort(.notFound) }

        let existing = try await EventLikeModel.query(on: req.db)
            .filter(\.$eventId == eventId)
            .filter(\.$userId == userId)
            .first()
        if existing == nil {
            try await EventLikeModel(eventId: eventId, userId: userId).create(on: req.db)
        }
        return try await Self.summary(eventId: eventId, viewerId: userId, on: req.db)
    }

    func unlike(req: Request) async throws -> LikeSummary {
        let token = try req.auth.require(UserToken.self)
        let userId = try token.requireUserID()
        let eventId = try id(req)
        try await EventLikeModel.query(on: req.db)
            .filter(\.$eventId == eventId)
            .filter(\.$userId == userId)
            .delete()
        return try await Self.summary(eventId: eventId, viewerId: userId, on: req.db)
    }

    // MARK: Helpers

    private func id(_ req: Request) throws -> UUID {
        guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest) }
        return id
    }

    private static func summary(eventId: UUID, viewerId: UUID?, on db: Database) async throws -> LikeSummary {
        let count = try await EventLikeModel.query(on: db).filter(\.$eventId == eventId).count()
        var liked = false
        if let viewerId {
            liked = try await EventLikeModel.query(on: db)
                .filter(\.$eventId == eventId)
                .filter(\.$userId == viewerId)
                .first() != nil
        }
        return LikeSummary(eventID: eventId, count: count, likedByViewer: liked)
    }

    /// The display name to attribute a comment to: the profile display name when
    /// present, otherwise the local part of the account email.
    private static func authorName(for userId: UUID, on db: Database) async throws -> String {
        guard let user = try await UserModel.find(userId, on: db) else { throw Abort(.notFound) }
        if let creatorId = user.creatorId, let creator = try await CreatorModel.find(creatorId, on: db) {
            return creator.displayName
        }
        return String(user.email.prefix(while: { $0 != "@" }))
    }
}
