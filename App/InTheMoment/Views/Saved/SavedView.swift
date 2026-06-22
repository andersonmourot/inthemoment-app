import SwiftUI
import InTheMomentCore

/// A fan's saved content: favorited events and followed creators.
struct SavedView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingAuth = false

    var body: some View {
        NavigationStack {
            Group {
                let favorites = model.favoriteEvents
                let following = model.followedCreators
                if favorites.isEmpty && following.isEmpty {
                    ContentUnavailableViewCompat(
                        title: "Nothing saved yet",
                        systemImage: "heart",
                        message: "Tap the heart on an event to favorite it, or follow creators to see their work here."
                    )
                } else {
                    List {
                        if !model.isAccountSignedIn {
                            Section {
                                Button {
                                    showingAuth = true
                                } label: {
                                    Label("Sign in to sync across devices", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.subheadline.weight(.semibold))
                                }
                            } footer: {
                                Text("Your favorites and follows are saved on this device. Sign in to sync them everywhere.")
                            }
                        }
                        if !favorites.isEmpty {
                            Section("Favorite events") {
                                ForEach(favorites) { event in
                                    NavigationLink(value: event.id) {
                                        SavedEventRow(event: event, creator: model.creator(id: event.creatorId))
                                    }
                                }
                            }
                        }
                        if !following.isEmpty {
                            Section("Following") {
                                ForEach(following) { creator in
                                    HStack(spacing: 12) {
                                        RemoteImage(url: creator.avatarURL)
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(creator.displayName).font(.subheadline.weight(.semibold))
                                            Text(creator.displayHandle).font(.caption).foregroundStyle(.appAccent)
                                        }
                                        Spacer()
                                        Button("Unfollow") {
                                            Task { await model.toggleFollow(creator.id) }
                                        }
                                        .font(.caption)
                                        .buttonStyle(.bordered)
                                        .tint(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Saved")
            .navigationDestination(for: UUID.self) { id in
                if let event = model.event(id: id) {
                    EventDetailView(event: event)
                }
            }
            .refreshable { await model.refresh() }
            .sheet(isPresented: $showingAuth) {
                AuthView()
            }
        }
    }
}

private struct SavedEventRow: View {
    let event: Event
    let creator: Creator?

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(url: event.displayCoverURL)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.headline)
                Text("\(creator?.displayName ?? "Unknown") · \(event.date.eventDayString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SavedView().environmentObject(AppModel())
}
