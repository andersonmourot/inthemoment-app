import Foundation

/// An in-memory ``EventStore`` used for development, previews and tests.
///
/// Backed by an actor so concurrent access from the UI is safe. Seed it with
/// ``SampleData`` for a populated experience, or start empty.
public actor InMemoryEventStore: EventStore {
    private var creators: [UUID: Creator]
    private var events: [UUID: Event]

    public init(creators: [Creator] = [], events: [Event] = []) {
        self.creators = Dictionary(uniqueKeysWithValues: creators.map { ($0.id, $0) })
        self.events = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
    }

    // MARK: Creators

    public func allCreators() async throws -> [Creator] {
        creators.values.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    public func creator(id: UUID) async throws -> Creator? {
        creators[id]
    }

    public func upsertCreator(_ creator: Creator) async throws {
        guard Creator.isValidHandle(creator.handle) else {
            throw EventStoreError.validation("Invalid handle: \(creator.handle)")
        }
        let clash = creators.values.first { $0.handle == creator.handle && $0.id != creator.id }
        if clash != nil {
            throw EventStoreError.duplicateHandle(creator.handle)
        }
        creators[creator.id] = creator
    }

    // MARK: Events

    public func publishedEvents() async throws -> [Event] {
        events.values
            .filter { $0.isPublished }
            .sorted { $0.date > $1.date }
    }

    public func events(forCreator creatorId: UUID) async throws -> [Event] {
        events.values
            .filter { $0.creatorId == creatorId }
            .sorted { $0.date > $1.date }
    }

    public func event(id: UUID) async throws -> Event? {
        events[id]
    }

    public func createEvent(_ event: Event) async throws {
        guard Event.isValidTitle(event.title) else {
            throw EventStoreError.validation("Event title must be 1–100 characters.")
        }
        guard creators[event.creatorId] != nil else {
            throw EventStoreError.creatorNotFound(event.creatorId)
        }
        events[event.id] = event
    }

    public func updateEvent(_ event: Event) async throws {
        guard events[event.id] != nil else {
            throw EventStoreError.eventNotFound(event.id)
        }
        guard Event.isValidTitle(event.title) else {
            throw EventStoreError.validation("Event title must be 1–100 characters.")
        }
        events[event.id] = event
    }

    public func deleteEvent(id: UUID) async throws {
        guard events.removeValue(forKey: id) != nil else {
            throw EventStoreError.eventNotFound(id)
        }
    }

    // MARK: Media

    public func addMedia(_ item: MediaItem, toEvent eventId: UUID) async throws {
        guard var event = events[eventId] else {
            throw EventStoreError.eventNotFound(eventId)
        }
        guard item.eventId == eventId else {
            throw EventStoreError.validation("Media item's eventId does not match the target event.")
        }
        event.media.append(item)
        events[eventId] = event
    }

    public func removeMedia(id: UUID, fromEvent eventId: UUID) async throws {
        guard var event = events[eventId] else {
            throw EventStoreError.eventNotFound(eventId)
        }
        guard event.media.contains(where: { $0.id == id }) else {
            throw EventStoreError.mediaNotFound(id)
        }
        event.media.removeAll { $0.id == id }
        events[eventId] = event
    }
}
