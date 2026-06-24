import SwiftUI
import InTheMomentCore

/// Public feed of published events from every creator.
struct DiscoverView: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""

    private var results: [Event] {
        EventFeed.search(model.events, query: query)
    }

    var body: some View {
        NavigationStack {
            AsyncContentView(
                isLoading: model.isLoading,
                hasLoaded: model.hasLoaded,
                isEmpty: model.events.isEmpty,
                errorMessage: model.loadError,
                retry: { await model.refresh() }
            ) {
                    List {
                        ForEach(results) { event in
                            NavigationLink(value: event.id) {
                                EventRow(event: event, creator: model.creator(id: event.creatorId))
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
            } empty: {
                ContentUnavailableViewCompat(
                    title: "No events yet",
                    systemImage: "sparkles",
                    message: "Published events from creators will show up here."
                )
            }
            .navigationTitle("EncoreMoment")
            .navigationDestination(for: UUID.self) { id in
                if let event = model.event(id: id) {
                    EventDetailView(event: event)
                }
            }
            .searchable(text: $query, prompt: "Search events")
            .refreshable { await model.refresh() }
        }
    }
}

private struct EventRow: View {
    let event: Event
    let creator: Creator?
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RemoteImage(url: event.displayCoverURL)
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .topTrailing) {
                    Button {
                        Task { await model.toggleFavorite(event.id) }
                    } label: {
                        Image(systemName: model.isFavorite(event.id) ? "heart.fill" : "heart")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(model.isFavorite(event.id) ? .pink : .white)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
                .overlay(alignment: .bottomTrailing) {
                    MediaCountBadge(photos: event.photoCount, videos: event.videoCount)
                        .padding(8)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.headline)
                HStack(spacing: 6) {
                    if let creator {
                        Text(creator.displayName)
                        if creator.isVerified {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.appAccent)
                        }
                        Text("·")
                    }
                    Text(event.date.eventDayString)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MediaCountBadge: View {
    let photos: Int
    let videos: Int

    var body: some View {
        HStack(spacing: 8) {
            if photos > 0 { Label("\(photos)", systemImage: "photo") }
            if videos > 0 { Label("\(videos)", systemImage: "video") }
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

#Preview {
    DiscoverView().environmentObject(AppModel())
}
