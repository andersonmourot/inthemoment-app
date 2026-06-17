import SwiftUI
import InTheMomentCore

/// The signed-in creator's profile and a directory of other creators.
struct ProfileView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var auth: AuthService
    @State private var showingAuth = false

    var body: some View {
        NavigationStack {
            List {
                if let creator = model.currentCreator {
                    Section {
                        CreatorHeader(creator: creator)
                    }
                    Section {
                        Button(role: .destructive) {
                            auth.logout()
                            Task { await model.signOut() }
                        } label: {
                            Text("Sign Out")
                        }
                    }
                } else {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You're browsing as a viewer")
                                .font(.headline)
                            Text("Sign in or create a creator account to post photos and videos from your events.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Button {
                                showingAuth = true
                            } label: {
                                Text("Sign In / Create Account").bold()
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Creators on InTheMoment") {
                    ForEach(model.creators) { creator in
                        HStack {
                            Text(creator.displayName)
                            if creator.isVerified {
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(.appAccent)
                            }
                            Spacer()
                            if creator.id == model.currentCreator?.id {
                                Text("You").font(.caption).foregroundStyle(.appAccent)
                            }
                        }
                    }
                }

                Section {
                    Text("In The Moment lets artists and event companies share photos and videos from their events for fans to view and download.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingAuth) {
                AuthView()
            }
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
    ProfileView()
        .environmentObject(AppModel())
        .environmentObject(AuthService())
}
