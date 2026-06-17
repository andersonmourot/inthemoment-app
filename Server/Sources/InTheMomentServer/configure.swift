import Vapor
import Fluent
import FluentSQLiteDriver

public func configure(_ app: Application) async throws {
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
    try await app.autoMigrate()

    try await seedIfEmpty(app)

    try routes(app)
}
