import SwiftUI
import InTheMomentCore

/// A single event page: header plus its grid of downloadable photos and videos.
struct EventDetailView: View {
    let event: Event
    @EnvironmentObject private var model: AppModel
    @State private var selectedMedia: MediaItem?

    /// Always read the freshest copy from the model so newly added media appears.
    private var liveEvent: Event { model.event(id: event.id) ?? event }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RemoteImage(url: liveEvent.displayCoverURL)
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 6) {
                    Text(liveEvent.title).font(.title2.bold())
                    if let creator = model.creator(id: liveEvent.creatorId) {
                        Text(creator.displayHandle).foregroundStyle(.appAccent)
                    }
                    HStack(spacing: 12) {
                        Label(liveEvent.date.eventDayString, systemImage: "calendar")
                        if let location = liveEvent.location {
                            Label(location, systemImage: "mappin.and.ellipse")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    if let details = liveEvent.details {
                        Text(details).font(.body).padding(.top, 4)
                    }
                }

                Divider()

                if liveEvent.media.isEmpty {
                    ContentUnavailableViewCompat(
                        title: "No media yet",
                        systemImage: "photo.on.rectangle",
                        message: "Photos and videos for this event will appear here."
                    )
                    .frame(height: 200)
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
                ShareLink(
                    item: DeepLink.event(liveEvent.id).webURL,
                    subject: Text(liveEvent.title),
                    message: Text("Photos & videos from \(liveEvent.title) on In The Moment")
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .fullScreenCover(item: $selectedMedia) { item in
            MediaDetailView(item: item)
        }
    }
}
