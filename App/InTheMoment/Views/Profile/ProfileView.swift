import SwiftUI
import InTheMomentCore

/// The signed-in profile and a directory of other creators.
struct ProfileView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var auth: AuthService
    @State private var showingAuth = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            List {
                if let creator = model.currentCreator {
                    Section {
                        CreatorHeader(creator: creator)
                    }
                    signOutSection
                } else if let email = model.signedInEmail {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Signed in")
                                .font(.headline)
                            Text(email)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text("Your saved items, follows, comments, and likes sync across your devices.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }
                        .padding(.vertical, 4)
                    }
                    signOutSection
                } else {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You're browsing as a viewer")
                                .font(.headline)
                            Text("Sign in to sync your favorites and follows across devices, comment, like, and post events.")
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
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.appAccent)
                            }
                            Spacer()
                            if creator.id == model.currentCreator?.id {
                                Text("You").font(.caption).foregroundStyle(Color.appAccent)
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingAuth) {
                AuthView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                auth.logout()
                Task { await model.didSignOut() }
            } label: {
                Text("Sign Out")
            }
        }
    }
}

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppTheme.storageKey) private var appThemeRaw = AppTheme.system.rawValue

    private var selectedTheme: Binding<AppTheme> {
        Binding {
            AppTheme(rawValue: appThemeRaw) ?? .system
        } set: { newValue in
            appThemeRaw = newValue.rawValue
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Theme", selection: selectedTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose System to match your device, or force Light or Dark mode for this app.")
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("API", value: AppConfig.apiBaseURL.host ?? AppConfig.apiBaseURL.absoluteString)
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (version, build) {
        case let (version?, build?):
            return "\(version) (\(build))"
        case let (version?, nil):
            return version
        default:
            return "Unknown"
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
                .overlay(Circle().stroke(Color.appAccent, lineWidth: 2))
            VStack(alignment: .leading, spacing: 2) {
                Text(creator.displayName).font(.title3.bold())
                Text(creator.displayHandle).foregroundStyle(Color.appAccent)
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
