import Foundation

/// The type of media stored in an event.
public enum MediaKind: String, Codable, Sendable, CaseIterable {
    case photo
    case video
}

/// A single photo or video belonging to an event.
public struct MediaItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let eventId: UUID
    public var kind: MediaKind
    /// Full-resolution asset URL used for viewing and downloading.
    public var url: URL
    /// Optional smaller image used in grids and lists. For videos this is a poster frame.
    public var thumbnailURL: URL?
    public var caption: String?
    public var width: Int?
    public var height: Int?
    /// Duration in seconds; only meaningful for `.video`.
    public var durationSeconds: Double?
    /// Whether viewers are allowed to download this item to their device.
    public var isDownloadable: Bool
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        eventId: UUID,
        kind: MediaKind,
        url: URL,
        thumbnailURL: URL? = nil,
        caption: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        durationSeconds: Double? = nil,
        isDownloadable: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.eventId = eventId
        self.kind = kind
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.caption = caption
        self.width = width
        self.height = height
        self.durationSeconds = durationSeconds
        self.isDownloadable = isDownloadable
        self.createdAt = createdAt
    }

    /// The image URL preferred for display: the thumbnail when present, otherwise the full asset.
    public var previewURL: URL { thumbnailURL ?? url }

    /// `durationSeconds` formatted as `m:ss`, or `nil` when not a timed asset.
    public var formattedDuration: String? {
        guard kind == .video, let seconds = durationSeconds, seconds > 0 else { return nil }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
