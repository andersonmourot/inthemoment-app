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
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    /// The creator currently acting in "creator mode" (the signed-in account).
    @Published var currentCreator: Creator

    private let store: EventStore

    init(store: EventStore = SampleData.makeStore(), currentCreator: Creator = SampleData.aurora) {
        self.store = store
        self.currentCreator = currentCreator
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
            self.events = try await published
            self.creators = try await people
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func creator(id: UUID) -> Creator? {
        creators.first { $0.id == id }
    }

    func myEvents() -> [Event] {
        events.filter { $0.creatorId == currentCreator.id }
    }

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

    func deleteEvent(_ id: UUID) async {
        await perform { try await self.store.deleteEvent(id: id) }
    }

    func event(id: UUID) -> Event? {
        events.first { $0.id == id }
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
