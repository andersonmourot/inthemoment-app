import SwiftUI
import InTheMomentCore

/// A single event page: header plus its grid of downloadable photos and videos.
struct EventDetailView: View {
    let event: Event
    @EnvironmentObject private var model: AppModel
    @State private var selectedMedia: MediaItem?
    @State private var isDownloadingAll = false
    @State private var downloadMessage: String?
    @State private var likeSummary: LikeSummary?
    @State private var isTogglingLike = false

    /// Always read the freshest copy from the model so newly added media appears.
    private var liveEvent: Event { model.event(id: event.id) ?? event }

    private var isFavorite: Bool { model.isFavorite(liveEvent.id) }

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
                        HStack {
                            NavigationLink {
                                CreatorProfileView(creator: creator)
                            } label: {
                                Text(creator.displayHandle).foregroundStyle(Color.appAccent)
                            }
                            Spacer()
                            FollowButton(creator: creator)
                        }
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

                likeRow

                if liveEvent.downloadableCount > 0 {
                    Button {
                        downloadAll()
                    } label: {
                        Label(
                            isDownloadingAll ? "Saving…" : "Download all (\(liveEvent.downloadableCount))",
                            systemImage: "square.and.arrow.down.on.square"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isDownloadingAll)
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

                Divider()

                CommentsSection(event: liveEvent)
            }
            .padding()
        }
        .navigationTitle(liveEvent.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: liveEvent.id) {
            await model.recordView(liveEvent.id)
            likeSummary = await model.likeSummary(forEvent: liveEvent.id)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.toggleFavorite(liveEvent.id) }
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                }
                .tint(isFavorite ? .pink : Color.appAccent)
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: DeepLink.event(liveEvent.id).webURL,
                    subject: Text(liveEvent.title),
                    message: Text("Photos & videos from \(liveEvent.title) on EncoreMoment")
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .fullScreenCover(item: $selectedMedia) { item in
            MediaDetailView(item: item) {
                Task { await model.recordDownloads(eventID: liveEvent.id, count: 1) }
            }
        }
        .alert("Download", isPresented: Binding(
            get: { downloadMessage != nil },
            set: { if !$0 { downloadMessage = nil } }
        )) {
            Button("OK", role: .cancel) { downloadMessage = nil }
        } message: {
            Text(downloadMessage ?? "")
        }
    }

    private var likeRow: some View {
        let summary = likeSummary ?? LikeSummary(eventID: liveEvent.id)
        let liked = summary.likedByViewer
        return Button {
            toggleLike(currentlyLiked: liked)
        } label: {
            Label("\(summary.count)", systemImage: liked ? "hand.thumbsup.fill" : "hand.thumbsup")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .tint(liked ? Color.appAccent : .secondary)
        .disabled(isTogglingLike || !model.isAccountSignedIn)
        .accessibilityLabel(liked ? "Unlike" : "Like")
    }

    private func toggleLike(currentlyLiked: Bool) {
        isTogglingLike = true
        Task {
            defer { isTogglingLike = false }
            if let updated = await model.setLike(eventID: liveEvent.id, !currentlyLiked) {
                likeSummary = updated
            }
        }
    }

    private func downloadAll() {
        isDownloadingAll = true
        Task {
            defer { isDownloadingAll = false }
            do {
                let result = try await MediaDownloader.saveAllToPhotoLibrary(liveEvent.media)
                await model.recordDownloads(eventID: liveEvent.id, count: result.saved)
                downloadMessage = result.failed == 0
                    ? "Saved \(result.saved) item\(result.saved == 1 ? "" : "s") to your photo library."
                    : "Saved \(result.saved), \(result.failed) failed."
            } catch {
                downloadMessage = error.localizedDescription
            }
        }
    }
}

/// Follow / Following toggle for a creator.
private struct FollowButton: View {
    let creator: Creator
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let following = model.isFollowing(creator.id)
        Button {
            Task { await model.toggleFollow(creator.id) }
        } label: {
            Label(following ? "Following" : "Follow",
                  systemImage: following ? "checkmark" : "plus")
                .font(.caption.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .tint(following ? .secondary : Color.appAccent)
    }
}
