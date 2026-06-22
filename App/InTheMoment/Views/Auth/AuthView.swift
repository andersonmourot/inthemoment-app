import SwiftUI
import InTheMomentCore

/// Sign-in / sign-up form. Fans create an account with just email + password
/// (favorites/follows sync across devices); creators also set up a profile so
/// they can post events.
struct AuthView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    private enum Mode { case login, register }
    private enum AccountKind { case fan, creator }

    @State private var mode: Mode = .login
    @State private var accountKind: AccountKind = .fan

    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var handle = ""

    private var isCreatorRegistration: Bool { mode == .register && accountKind == .creator }

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

                if mode == .register {
                    Section {
                        Picker("Account type", selection: $accountKind) {
                            Text("Fan").tag(AccountKind.fan)
                            Text("Creator").tag(AccountKind.creator)
                        }
                        .pickerStyle(.segmented)
                    } footer: {
                        Text(accountKind == .fan
                             ? "Save favorites and follow creators — synced across your devices."
                             : "Post photos and videos from your events for fans to view and download.")
                    }
                }

                Section {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(mode == .register ? .newPassword : .password)
                }

                if isCreatorRegistration {
                    Section("Your creator profile") {
                        TextField("Display name", text: $displayName)
                        TextField("Handle (e.g. aurora_live)", text: $handle)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
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
        if isCreatorRegistration {
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
                switch accountKind {
                case .fan:
                    account = await auth.registerFan(email: email, password: password)
                case .creator:
                    account = await auth.register(email: email, password: password, displayName: displayName, handle: handle)
                }
            }
            if let account {
                await model.didSignIn(account)
                dismiss()
            }
        }
    }
}
