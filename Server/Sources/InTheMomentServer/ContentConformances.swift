import Vapor
import InTheMomentCore

// The Core DTOs are Codable & Sendable, so they can serve directly as Vapor
// request/response bodies. This keeps the API's JSON identical to what the iOS
// app's APIEventStore expects.
extension Creator: Content {}
extension Event: Content {}
extension MediaItem: Content {}
extension FanPreferences: Content {}
extension EventStats: Content {}
