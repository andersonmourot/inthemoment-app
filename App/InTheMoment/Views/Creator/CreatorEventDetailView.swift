import SwiftUI
import InTheMomentCore

/// Creator's view of one of their events: same content as the public page plus an
/// "Add media" action for uploading new photos and videos.
struct CreatorEventDetailView: View {
    let event: Event
    @EnvironmentObject private var model: AppModel
    @State private var showingAdd = false
    @State private var selectedMedia: MediaItem?

    private var liveEvent: Event { model.event(id: event.id) ?? event }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
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
        }
        .sheet(isPresented: $showingAdd) {
            AddMediaView(eventId: liveEvent.id)
        }
        .fullScreenCover(item: $selectedMedia) { MediaDetailView(item: $0) }
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
