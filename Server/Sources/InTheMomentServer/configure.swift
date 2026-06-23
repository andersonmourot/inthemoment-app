import Vapor
import Fluent
import FluentSQLiteDriver
import JWT

public func configure(_ app: Application) async throws {
    // JWT signing key (set JWT_SECRET in production).
    let secret = Environment.get("JWT_SECRET") ?? "dev-secret-change-me-in-production"
    await app.jwt.keys.add(hmac: .init(from: Array(secret.utf8)), digestAlgorithm: .sha256)

    // JSON coders that match the iOS app's APIEventStore contract (ISO-8601 dates).
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    ContentConfiguration.global.use(encoder: encoder, for: .json)
    ContentConfiguration.global.use(decoder: decoder, for: .json)

    // SQLite on a configurable path (a Fly volume in production).
    let dbPath = Environment.get("DATABASE_PATH") ?? "db.sqlite"
    app.databases.use(.sqlite(.file(dbPath)), as: .sqlite)

    app.migrations.add(CreateCreator())
    app.migrations.add(CreateEvent())
    app.migrations.add(CreateMedia())
    app.migrations.add(CreateUser())
    app.migrations.add(MakeUserCreatorOptional())
    app.migrations.add(CreateFavorite())
    app.migrations.add(CreateFollow())
    app.migrations.add(CreateEventStats())
    app.migrations.add(CreateComment())
    app.migrations.add(CreateEventLike())
    try await app.autoMigrate()

    try await seedIfEmpty(app)

    try routes(app)
}
