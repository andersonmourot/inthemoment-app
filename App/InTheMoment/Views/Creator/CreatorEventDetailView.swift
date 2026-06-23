import SwiftUI
import InTheMomentCore

/// Creator's view of one of their events: same content as the public page plus an
/// "Add media" action for uploading new photos and videos.
struct CreatorEventDetailView: View {
    let event: Event
    @EnvironmentObject private var model: AppModel
    @State private var showingAdd = false
    @State private var showingEdit = false
    @State private var selectedMedia: MediaItem?

    private var liveEvent: Event { model.event(id: event.id) ?? event }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                statsCard
                Divider()
                if liveEvent.media.isEmpty {
                    ContentUnavailableViewCompat(
                        title: "No media yet",
                        systemImage: "photo.badge.plus",
                        message: "Tap Add to upload photos and videos to this event."
                    )
                    .frame(height: 180)
                } else {
                    MediaGridView(media: liveEvent.media) { selectedMedia = $0 }
                }
            }
            .padding()
        }
        .navigationTitle(liveEvent.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: { Label("Add", systemImage: "plus") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingEdit = true } label: { Label("Edit details", systemImage: "pencil") }
                    Button {
                        Task { await model.setPublished(!liveEvent.isPublished, for: liveEvent.id) }
                    } label: {
                        if liveEvent.isPublished {
                            Label("Switch to draft", systemImage: "eye.slash")
                        } else {
                            Label("Publish", systemImage: "eye")
                        }
                    }
                    ShareLink(item: DeepLink.event(liveEvent.id).webURL) {
                        Label("Share link", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddMediaView(eventId: liveEvent.id)
        }
        .sheet(isPresented: $showingEdit) {
            EditEventView(event: liveEvent)
        }
        .fullScreenCover(item: $selectedMedia) { MediaDetailView(item: $0) }
    }

    private var statsCard: some View {
        let stats = model.stats(for: liveEvent.id)
        return HStack(spacing: 0) {
            StatTile(value: stats.views, label: "Views", systemImage: "eye")
            Divider().frame(height: 36)
            StatTile(value: stats.downloads, label: "Downloads", systemImage: "square.and.arrow.down")
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteImage(url: liveEvent.displayCoverURL)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            HStack(spacing: 12) {
                Label(liveEvent.date.eventDayString, systemImage: "calendar")
                if let location = liveEvent.location {
                    Label(location, systemImage: "mappin.and.ellipse")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            if let details = liveEvent.details {
                Text(details).padding(.top, 4)
            }
        }
    }
}

/// One labeled metric in the creator's stats card.
private struct StatTile: View {
    let value: Int
    let label: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 4) {
            Label("\(value)", systemImage: systemImage)
                .font(.title3.weight(.semibold))
                .labelStyle(.titleAndIcon)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
