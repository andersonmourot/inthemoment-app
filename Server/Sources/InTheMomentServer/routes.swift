import Vapor
import Fluent
import InTheMomentCore

func routes(_ app: Application) throws {
    app.get { _ async in "InTheMoment API is up" }
    app.get("health") { _ async in ["status": "ok"] }

    try app.register(collection: AuthController())
    try app.register(collection: CreatorController())
    try app.register(collection: EventController())
    try app.register(collection: FanController())
    try app.register(collection: AnalyticsController())
}

struct CreatorController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let creators = routes.grouped("creators")
        creators.get(use: index)
        creators.get(":id", use: show)

        let protected = creators.grouped(UserToken.authenticator(), UserToken.guardMiddleware())
        protected.put(":id", use: update)
    }

    func index(req: Request) async throws -> [Creator] {
        try await CreatorModel.query(on: req.db)
            .sort(\.$displayName)
            .all()
            .map { $0.toDTO() }
    }

    func show(req: Request) async throws -> Creator {
        guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest) }
        guard let model = try await CreatorModel.find(id, on: req.db) else { throw Abort(.notFound) }
        return model.toDTO()
    }

    /// Update a creator profile. Only the owning user may edit their own profile.
    func update(req: Request) async throws -> Creator {
        let token = try req.auth.require(UserToken.self)
        guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest) }
        guard try id == token.requireCreatorID() else { throw Abort(.forbidden) }
        guard let existing = try await CreatorModel.find(id, on: req.db) else { throw Abort(.notFound) }

        let dto = try req.content.decode(Creator.self)
        guard Creator.isValidHandle(dto.handle) else {
            throw Abort(.unprocessableEntity, reason: "Invalid handle")
        }
        existing.apply(dto)
        try await existing.save(on: req.db)
        return existing.toDTO()
    }
}

struct EventController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let events = routes.grouped("events")
        events.get(use: index)
        events.get(":id", use: show)

        let protected = events.grouped(UserToken.authenticator(), UserToken.guardMiddleware())
        protected.post(use: create)
        protected.put(":id", use: update)
        protected.delete(":id", use: delete)
        protected.post(":id", "media", use: addMedia)
        protected.delete(":id", "media", ":mediaId", use: removeMedia)
    }

    func index(req: Request) async throws -> [Event] {
        var query = EventModel.query(on: req.db).with(\.$media)
        if let published = req.query[Bool.self, at: "published"], published {
            query = query.filter(\.$isPublished == true)
        }
        if let creator = req.query[UUID.self, at: "creator"] {
            query = query.filter(\.$creatorId == creator)
        }
        return try await query.sort(\.$date, .descending).all().map { $0.toDTO() }
    }

    func show(req: Request) async throws -> Event {
        try await loadEvent(req).toDTO()
    }

    func create(req: Request) async throws -> Event {
        let token = try req.auth.require(UserToken.self)
        let dto = try req.content.decode(Event.self)
        guard Event.isValidTitle(dto.title) else {
            throw Abort(.unprocessableEntity, reason: "Event title must be 1–100 characters.")
        }
        // Ownership: the event is always attributed to the authenticated creator.
        let creatorId = try token.requireCreatorID()
        let model = EventModel(from: dto)
        model.creatorId = creatorId
        return try await req.db.transaction { db in
            try await model.create(on: db)
            for item in dto.media {
                let media = MediaModel(from: item)
                media.$event.id = dto.id
                try await media.create(on: db)
            }
            return try await Self.reload(dto.id, on: db).toDTO()
        }
    }

    func update(req: Request) async throws -> Event {
        let token = try req.auth.require(UserToken.self)
        guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest) }
        let dto = try req.content.decode(Event.self)
        guard Event.isValidTitle(dto.title) else {
            throw Abort(.unprocessableEntity, reason: "Event title must be 1–100 characters.")
        }
        let model = try await Self.requireOwnedEvent(id, token: token, on: req.db)
        return try await req.db.transaction { db in
            model.applyFields(dto)
            model.creatorId = try token.requireCreatorID()
            try await model.save(on: db)
            try await MediaModel.query(on: db).filter(\.$event.$id == id).delete()
            for item in dto.media {
                let media = MediaModel(from: item)
                media.$event.id = id
                try await media.create(on: db)
            }
            return try await Self.reload(id, on: db).toDTO()
        }
    }

    func delete(req: Request) async throws -> HTTPStatus {
        let token = try req.auth.require(UserToken.self)
        guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest) }
        let model = try await Self.requireOwnedEvent(id, token: token, on: req.db)
        try await model.delete(on: req.db)
        return .noContent
    }

    func addMedia(req: Request) async throws -> MediaItem {
        let token = try req.auth.require(UserToken.self)
        guard let eventId = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest) }
        _ = try await Self.requireOwnedEvent(eventId, token: token, on: req.db)
        let dto = try req.content.decode(MediaItem.self)
        let media = MediaModel(from: dto)
        media.$event.id = eventId
        try await media.create(on: req.db)
        return media.toDTO()
    }

    func removeMedia(req: Request) async throws -> HTTPStatus {
        let token = try req.auth.require(UserToken.self)
        guard let eventId = req.parameters.get("id", as: UUID.self),
              let mediaId = req.parameters.get("mediaId", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        _ = try await Self.requireOwnedEvent(eventId, token: token, on: req.db)
        guard let media = try await MediaModel.query(on: req.db)
            .filter(\.$id == mediaId)
            .filter(\.$event.$id == eventId)
            .first() else {
            throw Abort(.notFound)
        }
        try await media.delete(on: req.db)
        return .noContent
    }

    // MARK: Helpers

    private func loadEvent(_ req: Request) async throws -> EventModel {
        guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest) }
        return try await Self.reload(id, on: req.db)
    }

    /// Loads an event and asserts the token's creator owns it.
    private static func requireOwnedEvent(_ id: UUID, token: UserToken, on db: Database) async throws -> EventModel {
        let creatorId = try token.requireCreatorID()
        guard let model = try await EventModel.find(id, on: db) else { throw Abort(.notFound) }
        guard model.creatorId == creatorId else { throw Abort(.forbidden) }
        return model
    }

    private static func reload(_ id: UUID, on db: Database) async throws -> EventModel {
        guard let model = try await EventModel.query(on: db)
            .filter(\.$id == id)
            .with(\.$media)
            .first() else {
            throw Abort(.notFound)
        }
        return model
    }
}
