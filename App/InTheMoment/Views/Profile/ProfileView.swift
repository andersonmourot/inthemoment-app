import SwiftUI
import InTheMomentCore

/// The signed-in creator's profile and a directory of other creators.
struct ProfileView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    CreatorHeader(creator: model.currentCreator)
                }

                Section("Switch acting creator") {
                    ForEach(model.creators) { creator in
                        Button {
                            Task { await model.switchCreator(to: creator) }
                        } label: {
                            HStack {
                                Text(creator.displayName)
                                if creator.isVerified {
                                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.appAccent)
                                }
                                Spacer()
                                if creator.id == model.currentCreator.id {
                                    Image(systemName: "checkmark").foregroundStyle(.appAccent)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                }

                Section {
                    Text("In The Moment lets artists and event companies share photos and videos from their events for fans to view and download.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Profile")
        }
    }
}

private struct CreatorHeader: View {
    let creator: Creator

    var body: some View {
        HStack(spacing: 14) {
            RemoteImage(url: creator.avatarURL)
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                .overlay(Circle().stroke(.appAccent, lineWidth: 2))
            VStack(alignment: .leading, spacing: 2) {
                Text(creator.displayName).font(.title3.bold())
                Text(creator.displayHandle).foregroundStyle(.appAccent)
                if let bio = creator.bio {
                    Text(bio).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProfileView().environmentObject(AppModel())
}
