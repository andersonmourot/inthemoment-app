import XCTest
@testable import InTheMomentCore

final class FanPreferencesTests: XCTestCase {
    func testFavoriteAndFollowToggling() {
        var prefs = FanPreferences()
        let event = UUID(), creator = UUID()

        XCTAssertFalse(prefs.isFavorite(event))
        prefs.setFavorite(event, true)
        XCTAssertTrue(prefs.isFavorite(event))
        prefs.setFavorite(event, false)
        XCTAssertFalse(prefs.isFavorite(event))

        prefs.setFollowing(creator, true)
        XCTAssertTrue(prefs.isFollowing(creator))
        prefs.setFollowing(creator, false)
        XCTAssertFalse(prefs.isFollowing(creator))
    }

    func testInMemoryStoreRoundTrip() async throws {
        let store = InMemoryFanPreferencesStore()
        let event = UUID()
        let updated = try await store.setFavorite(eventID: event, true)
        XCTAssertTrue(updated.isFavorite(event))
        let reloaded = try await store.preferences()
        XCTAssertEqual(reloaded.favoriteEventIDs, [event])
    }

    func testFileStorePersistsAcrossInstances() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("fan.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let event = UUID(), creator = UUID()
        let store = try FileFanPreferencesStore(fileURL: url)
        try await store.setFavorite(eventID: event, true)
        try await store.setFollowing(creatorID: creator, true)

        let reopened = try FileFanPreferencesStore(fileURL: url)
        let prefs = try await reopened.preferences()
        XCTAssertEqual(prefs.favoriteEventIDs, [event])
        XCTAssertEqual(prefs.followedCreatorIDs, [creator])
    }

    func testFeedFiltersByFavoritesAndFollows() {
        let creatorA = UUID(), creatorB = UUID()
        let e1 = Event(creatorId: creatorA, title: "A1", date: Date(timeIntervalSince1970: 100))
        let e2 = Event(creatorId: creatorB, title: "B1", date: Date(timeIntervalSince1970: 200))
        let e3 = Event(creatorId: creatorA, title: "A2", date: Date(timeIntervalSince1970: 300))
        let events = [e1, e2, e3]

        let followed = EventFeed.events(events, byCreators: [creatorA])
        XCTAssertEqual(Set(followed.map(\.id)), [e1.id, e3.id])

        let favorites = EventFeed.events(events, withIDs: [e1.id, e2.id])
        XCTAssertEqual(favorites.map(\.id), [e2.id, e1.id]) // newest first
    }
}
