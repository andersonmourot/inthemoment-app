import Vapor
import Fluent
import InTheMomentCore

func routes(_ app: Application) throws {
    app.get { _ async in "InTheMoment API is up" }
    app.get("health") { _ async in ["status": "ok"] }

    try app.register(collection: CreatorController())
    try app.register(collection: EventController())
}

struct CreatorController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let creators = routes.grouped("creators")
        creators.get(use: index)
        creators.get(":id", use: show)
        creators.put(":id", use: upsert)
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

    func upsert(req: Request) async throws -> Creator {
        guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest) }
        let dto = try req.content.decode(Creator.self)
        guard Creator.isValidHandle(dto.handle) else {
            throw Abort(.unprocessableEntity, reason: "Invalid handle")
        }
        if let existing = try await CreatorModel.find(id, on: req.db) {
            existing.apply(dto)
            try await existing.save(on: req.db)
            return existing.toDTO()
        }
        let model = CreatorModel(from: dto)
        model.id = id
        try await model.create(on: req.db)
        return model.toDTO()
    }
}

struct EventController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let events = routes.grouped("events")
        events.get(use: index)
        events.get(":id", use: show)
        events.post(use: create)
        events.put(":id", use: update)
        events.delete(":id", use: delete)
        events.post(":id", "media", use: addMedia)
        events.delete(":id", "media", ":mediaId", use: removeMedia)
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
        let dto = try req.content.decode(Event.self)
        guard Event.isValidTitle(dto.title) else {
            throw Abort(.unprocessableEntity, reason: "Event title must be 1–100 characters.")
        }
        return try await req.db.transaction { db in
            let model = EventModel(from: dto)
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
        guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest) }
        let dto = try req.content.decode(Event.self)
        guard Event.isValidTitle(dto.title) else {
            throw Abort(.unprocessableEntity, reason: "Event title must be 1–100 characters.")
        }
        guard let model = try await EventModel.find(id, on: req.db) else { throw Abort(.notFound) }
        return try await req.db.transaction { db in
            model.applyFields(dto)
            try await model.save(on: db)
            // Replace the media set with the payload's media.
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
        guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest) }
        guard let model = try await EventModel.find(id, on: req.db) else { throw Abort(.notFound) }
        try await model.delete(on: req.db)
        return .noContent
    }

    func addMedia(req: Request) async throws -> MediaItem {
        guard let eventId = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest) }
        guard try await EventModel.find(eventId, on: req.db) != nil else { throw Abort(.notFound) }
        let dto = try req.content.decode(MediaItem.self)
        let media = MediaModel(from: dto)
        media.$event.id = eventId
        try await media.create(on: req.db)
        return media.toDTO()
    }

    func removeMedia(req: Request) async throws -> HTTPStatus {
        guard let eventId = req.parameters.get("id", as: UUID.self),
              let mediaId = req.parameters.get("mediaId", as: UUID.self) else {
            throw Abort(.badRequest)
        }
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
