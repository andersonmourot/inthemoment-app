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
    @Published var errorMessage: String?

    /// The creator currently acting in "creator mode" (the signed-in account).
    @Published var currentCreator: Creator

    /// Event to present when the app is opened via a deep link.
    @Published var deepLinkedEvent: Event?

    private let store: EventStore

    init(store: EventStore? = nil, currentCreator: Creator = SampleData.aurora) {
        self.store = store ?? AppModel.makeDefaultStore()
        self.currentCreator = currentCreator
    }

    /// The shared backend so events and uploads are visible across all users.
    private static func makeDefaultStore() -> EventStore {
        APIEventStore(baseURL: AppConfig.apiBaseURL)
    }

    func bootstrap() async {
        await refresh()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let published = store.publishedEvents()
            async let people = store.allCreators()
            async let mine = store.events(forCreator: currentCreator.id)
            self.events = try await published
            self.creators = try await people
            self.myEventsList = try await mine
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func creator(id: UUID) -> Creator? {
        creators.first { $0.id == id }
    }

    func myEvents() -> [Event] { myEventsList }

    // MARK: Mutations

    func createEvent(title: String, details: String?, location: String?, date: Date) async {
        let event = Event(
            creatorId: currentCreator.id,
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

    func switchCreator(to creator: Creator) async {
        currentCreator = creator
        await refresh()
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
