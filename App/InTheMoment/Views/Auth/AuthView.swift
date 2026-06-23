import SwiftUI
import InTheMomentCore

/// Sign-in / sign-up form. Every account has a profile for posting events, while
/// favorites/follows sync across devices once signed in.
struct AuthView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    private enum Mode { case login, register }

    @State private var mode: Mode = .login

    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var handle = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Mode", selection: $mode) {
                    Text("Sign In").tag(Mode.login)
                    Text("Create Account").tag(Mode.register)
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(mode == .register ? .newPassword : .password)
                }

                if mode == .register {
                    Section {
                        TextField("Display name", text: $displayName)
                        TextField("Handle (e.g. aurora_live)", text: $handle)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Text("Handle must be 3-30 characters using only lowercase letters, numbers, and underscores.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Your profile")
                    } footer: {
                        Text("Use this profile to post events, comment, follow creators, and sync your saved items.")
                    }
                }

                if let error = auth.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }
                }

                Section {
                    Button(action: submit) {
                        HStack {
                            Spacer()
                            if auth.isWorking {
                                ProgressView()
                            } else {
                                Text(mode == .login ? "Sign In" : "Create Account").bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(auth.isWorking || !isValid)
                }
            }
            .navigationTitle(mode == .login ? "Welcome back" : "Join InTheMoment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var isValid: Bool {
        let base = email.contains("@") && password.count >= 8
        if mode == .register {
            return base && !displayName.trimmingCharacters(in: .whitespaces).isEmpty
                && Creator.isValidHandle(handle)
        }
        return base
    }

    private func submit() {
        Task {
            let account: Account?
            switch mode {
            case .login:
                account = await auth.login(email: email, password: password)
            case .register:
                account = await auth.register(email: email, password: password, displayName: displayName, handle: handle)
            }
            if let account {
                await model.didSignIn(account)
                dismiss()
            }
        }
    }
}
