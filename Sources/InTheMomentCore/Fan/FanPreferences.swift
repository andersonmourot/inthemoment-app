import Foundation

/// A fan's personal, per-device preferences: which events they've favorited and
/// which creators they follow.
///
/// Fans browse without an account, so this is stored locally (see
/// ``FanPreferencesStore``). It's a plain `Codable` value type so it can later be
/// synced to a server if fan accounts are added.
public struct FanPreferences: Codable, Sendable, Equatable {
    public var favoriteEventIDs: Set<UUID>
    public var followedCreatorIDs: Set<UUID>

    public init(favoriteEventIDs: Set<UUID> = [], followedCreatorIDs: Set<UUID> = []) {
        self.favoriteEventIDs = favoriteEventIDs
        self.followedCreatorIDs = followedCreatorIDs
    }

    public func isFavorite(_ eventID: UUID) -> Bool { favoriteEventIDs.contains(eventID) }
    public func isFollowing(_ creatorID: UUID) -> Bool { followedCreatorIDs.contains(creatorID) }

    public mutating func setFavorite(_ eventID: UUID, _ isFavorite: Bool) {
        if isFavorite { favoriteEventIDs.insert(eventID) } else { favoriteEventIDs.remove(eventID) }
    }

    public mutating func setFollowing(_ creatorID: UUID, _ isFollowing: Bool) {
        if isFollowing { followedCreatorIDs.insert(creatorID) } else { followedCreatorIDs.remove(creatorID) }
    }
}
