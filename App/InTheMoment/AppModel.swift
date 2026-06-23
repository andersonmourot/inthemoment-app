import Foundation
import InTheMomentCore

/// Observable view-model that bridges SwiftUI views to the ``EventStore``.
///
/// Holds the lightweight UI state (loaded events, the "signed in" creator) and
/// exposes async actions the views call. The concrete store is injected, so
/// swapping ``InMemoryEventStore`` for a networked store later is a one-line change.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var events: [Event] = []
    @Published private(set) var creators: [Creator] = []
    /// Events owned by the current creator, including unpublished drafts.
    @Published private(set) var myEventsList: [Event] = []
    @Published private(set) var isLoading = false
    /// Whether the first load attempt has completed (used to distinguish the
    /// initial loading state from a genuinely empty feed).
    @Published private(set) var hasLoaded = false
    /// Set when loading the feed fails; surfaced inline with a Retry action.
    @Published private(set) var loadError: String?
    /// Set when a one-off action (create/update/delete) fails; surfaced as an alert.
    @Published var errorMessage: String?

    /// The creator currently acting in "creator mode" (the signed-in account),
    /// or `nil` when browsing as an anonymous viewer or a fan.
    @Published var currentCreator: Creator?

    /// The email of the signed-in account (creator or fan), or `nil` if anonymous.
    @Published private(set) var signedInEmail: String?

    /// Whether a creator is signed in (creator-only features are gated on this).
    var isSignedIn: Bool { currentCreator != nil }

    /// Whether any account (creator or fan) is signed in.
    var isAccountSignedIn: Bool { signedInEmail != nil }

    /// Event to present when the app is opened via a deep link.
    @Published var deepLinkedEvent: Event?

    /// The fan's on-device favorites and followed creators.
    @Published private(set) var fanPrefs = FanPreferences()

    /// Engagement stats for the current creator's events, keyed by event id.
    @Published private(set) var statsByEvent: [UUID: EventStats] = [:]

    private let store: EventStore
    /// Swapped between the on-device file store (anonymous) and the API store
    /// (signed in) so favorites/follows sync to the account when logged in.
    private var fanStore: FanPreferencesStore
    private let analyticsStore: AnalyticsStore

    init(
        store: EventStore? = nil,
        fanStore: FanPreferencesStore? = nil,
        analyticsStore: AnalyticsStore? = nil,
        currentCreator: Creator? = nil
    ) {
        self.store = store ?? AppModel.makeDefaultStore()
        self.fanStore = fanStore ?? AppModel.makeDefaultFanStore()
        self.analyticsStore = analyticsStore ?? AppModel.makeDefaultAnalyticsStore()
        self.currentCreator = currentCreator
    }

    /// The shared backend so events and uploads are visible across all users.
    /// Wrapped in an ``AuthenticatedTransport`` so mutations carry the bearer token.
    private static func makeDefaultStore() -> EventStore {
        let transport = AuthenticatedTransport { TokenHolder.shared.token }
        return APIEventStore(baseURL: AppConfig.apiBaseURL, transport: transport)
    }

    private static func makeDefaultFanStore() -> FanPreferencesStore {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("fan-preferences.json")
        return (try? FileFanPreferencesStore(fileURL: url)) ?? InMemoryFanPreferencesStore()
    }

    /// The account-backed fan store (favorites/follows sync across devices).
    private static func makeAPIFanStore() -> FanPreferencesStore {
        let transport = AuthenticatedTransport { TokenHolder.shared.token }
        return APIFanPreferencesStore(baseURL: AppConfig.apiBaseURL, transport: transport)
    }

    private static func makeDefaultAnalyticsStore() -> AnalyticsStore {
        let transport = AuthenticatedTransport { TokenHolder.shared.token }
        return APIAnalyticsStore(baseURL: AppConfig.apiBaseURL, transport: transport)
    }

    /// Loads initial data. When restoring a signed-in `account`, switches to the
    /// account-backed fan store so favorites/follows come from the server.
    func bootstrap(account: Account? = nil) async {
        if let account {
            currentCreator = account.creator
            signedInEmail = account.email
            fanStore = AppModel.makeAPIFanStore()
        }
        fanPrefs = (try? await fanStore.preferences()) ?? FanPreferences()
        await refresh()
    }

    func refresh() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false; hasLoaded = true }
        do {
            async let published = store.publishedEvents()
            async let people = store.allCreators()
            self.events = try await published
            self.creators = try await people
            if let creator = currentCreator {
                self.myEventsList = try await store.events(forCreator: creator.id)
            } else {
                self.myEventsList = []
            }
        } catch {
            loadError = error.localizedDescription
        }
        await loadCreatorStats()
    }

    // MARK: Analytics

    /// Stats for one of the creator's events (zeroes until loaded/recorded).
    func stats(for eventID: UUID) -> EventStats {
        statsByEvent[eventID] ?? EventStats(eventID: eventID)
    }

    /// Loads engagement stats for every event owned by the signed-in creator.
    private func loadCreatorStats() async {
        guard currentCreator != nil else {
            statsByEvent = [:]
            return
        }
        if let stats = try? await analyticsStore.creatorStats() {
            statsByEvent = Dictionary(stats.map { ($0.eventID, $0) }, uniquingKeysWith: { a, _ in a })
        }
    }

    /// Records that a fan opened an event page. Fire-and-forget.
    func recordView(_ eventID: UUID) async {
        try? await analyticsStore.recordView(eventID: eventID)
    }

    /// Records `count` downloads from an event. Fire-and-forget.
    func recordDownloads(eventID: UUID, count: Int) async {
        guard count > 0 else { return }
        try? await analyticsStore.recordDownloads(eventID: eventID, count: count)
    }

    func creator(id: UUID) -> Creator? {
        creators.first { $0.id == id }
    }

    func myEvents() -> [Event] { myEventsList }

    // MARK: Mutations

    func createEvent(title: String, details: String?, location: String?, date: Date) async {
        guard let creator = currentCreator else { return }
        let event = Event(
            creatorId: creator.id,
            title: title,
            details: details?.nilIfBlank,
            location: location?.nilIfBlank,
            date: date
        )
        await perform { try await self.store.createEvent(event) }
    }

    func addMedia(_ item: MediaItem, to eventId: UUID) async {
        await perform { try await self.store.addMedia(item, toEvent: eventId) }
    }

    func updateEvent(_ event: Event) async {
        await perform { try await self.store.updateEvent(event) }
    }

    func setPublished(_ isPublished: Bool, for eventId: UUID) async {
        guard var event = await resolveEvent(id: eventId) else { return }
        event.isPublished = isPublished
        await updateEvent(event)
    }

    func deleteEvent(_ id: UUID) async {
        await perform { try await self.store.deleteEvent(id: id) }
    }

    /// Resolves and presents an event opened via a ``DeepLink`` URL.
    func handle(url: URL) async {
        guard case .event(let id)? = DeepLink(url: url) else { return }
        deepLinkedEvent = await resolveEvent(id: id)
    }

    /// Looks up an event from the loaded feed, falling back to the store.
    private func resolveEvent(id: UUID) async -> Event? {
        if let local = event(id: id) { return local }
        return (try? await store.event(id: id)) ?? nil
    }

    func event(id: UUID) -> Event? {
        events.first { $0.id == id } ?? myEventsList.first { $0.id == id }
    }

    /// Called after a successful sign-in/registration. Switches to the account's
    /// server-backed fan store and merges any on-device favorites/follows up to it
    /// so nothing collected while anonymous is lost.
    func didSignIn(_ account: Account) async {
        let local = (try? await fanStore.preferences()) ?? fanPrefs
        currentCreator = account.creator
        signedInEmail = account.email
        let api = AppModel.makeAPIFanStore()
        fanStore = api
        if let merged = try? await api.merge(local) {
            fanPrefs = merged
        } else {
            fanPrefs = (try? await api.preferences()) ?? FanPreferences()
        }
        await refresh()
    }

    /// Clears account state on sign-out (token is cleared separately by AuthService)
    /// and returns to the on-device fan store.
    func didSignOut() async {
        currentCreator = nil
        signedInEmail = nil
        myEventsList = []
        fanStore = AppModel.makeDefaultFanStore()
        fanPrefs = (try? await fanStore.preferences()) ?? FanPreferences()
        await refresh()
    }

    // MARK: Fan preferences (favorites & follows)

    func isFavorite(_ eventID: UUID) -> Bool { fanPrefs.isFavorite(eventID) }
    func isFollowing(_ creatorID: UUID) -> Bool { fanPrefs.isFollowing(creatorID) }

    func toggleFavorite(_ eventID: UUID) async {
        let newValue = !fanPrefs.isFavorite(eventID)
        do {
            fanPrefs = try await fanStore.setFavorite(eventID: eventID, newValue)
        } catch {
            errorMessage = "Couldn't \(newValue ? "save" : "remove") this favorite. Please try again."
        }
    }

    func toggleFollow(_ creatorID: UUID) async {
        let newValue = !fanPrefs.isFollowing(creatorID)
        do {
            fanPrefs = try await fanStore.setFollowing(creatorID: creatorID, newValue)
        } catch {
            errorMessage = "Couldn't \(newValue ? "follow" : "unfollow") right now. Please try again."
        }
    }

    /// Favorited events that are still available in the loaded feed, newest first.
    var favoriteEvents: [Event] {
        EventFeed.events(events, withIDs: fanPrefs.favoriteEventIDs)
    }

    /// Creators the fan follows.
    var followedCreators: [Creator] {
        creators.filter { fanPrefs.isFollowing($0.id) }
    }

    /// Published events from creators the fan follows, newest first.
    var followedEvents: [Event] {
        EventFeed.sortedByDate(EventFeed.events(events, byCreators: fanPrefs.followedCreatorIDs))
    }

    private func perform(_ action: @escaping () async throws -> Void) async {
        do {
            try await action()
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
