import Foundation

/// A page created by a creator that holds the photos and videos for one event.
/// Each event is independent and owns its own media collection.
public struct Event: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let creatorId: UUID
    public var title: String
    public var details: String?
    public var coverImageURL: URL?
    public var location: String?
    /// When the event itself took place.
    public var date: Date
    /// When the event page was created on the platform.
    public let createdAt: Date
    /// Whether the event is visible to viewers in Discover.
    public var isPublished: Bool
    public var media: [MediaItem]

    public init(
        id: UUID = UUID(),
        creatorId: UUID,
        title: String,
        details: String? = nil,
        coverImageURL: URL? = nil,
        location: String? = nil,
        date: Date = Date(),
        createdAt: Date = Date(),
        isPublished: Bool = true,
        media: [MediaItem] = []
    ) {
        self.id = id
        self.creatorId = creatorId
        self.title = title
        self.details = details
        self.coverImageURL = coverImageURL
        self.location = location
        self.date = date
        self.createdAt = createdAt
        self.isPublished = isPublished
        self.media = media
    }

    public var photoCount: Int { media.lazy.filter { $0.kind == .photo }.count }
    public var videoCount: Int { media.lazy.filter { $0.kind == .video }.count }
    public var mediaCount: Int { media.count }

    /// Cover image to display, falling back to the first media preview when no cover is set.
    public var displayCoverURL: URL? { coverImageURL ?? media.first?.previewURL }
}

public extension Event {
    /// Validates a title once trimmed: must be 1–100 characters.
    static func isValidTitle(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return (1...100).contains(trimmed.count)
    }
}
