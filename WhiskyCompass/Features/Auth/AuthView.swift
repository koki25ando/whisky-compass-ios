import SwiftUI

@Observable
final class AuthViewModel {
    var email = ""
    var displayName = ""
    var password = ""
    var isSubmitting = false
    var error: String?
    var fieldErrors: [String: String] = [:]
    var isDone = false

    private let repository = AuthRepository.shared

    var canSubmitLogin: Bool {
        !email.isEmpty && !password.isEmpty && !isSubmitting
    }

    var canSubmitSignUp: Bool {
        canSubmitLogin && !displayName.isEmpty
    }

    func logIn() {
        submit { [self] in
            try await repository.logIn(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
        }
    }

    func signUp() {
        submit { [self] in
            try await repository.signUp(
                email: email.trimmingCharacters(in: .whitespaces),
                displayName: displayName.trimmingCharacters(in: .whitespaces),
                password: password
            )
        }
    }

    private func submit(_ action: @escaping () async throws -> Void) {
        guard !isSubmitting else { return }
        isSubmitting = true
        error = nil
        fieldErrors = [:]

        Task { @MainActor in
            do {
                try await action()
                isSubmitting = false
                isDone = true
            } catch let apiError as APIError {
                isSubmitting = false
                // 認証失敗は401で返る。「メールかパスワードが違う」と伝えるほうが親切。
                if case .unauthorized = apiError {
                    error = "Email or password is incorrect."
                } else {
                    error = apiError.message
                    fieldErrors = apiError.fieldErrors
                }
            } catch {
                isSubmitting = false
                self.error = APIError.unknown.message
            }
        }
    }
}

struct AuthView: View {
    enum Mode {
        case logIn, signUp
    }

    let mode: Mode
    let onFinished: () -> Void
    let onSwitchMode: () -> Void

    @State private var viewModel = AuthViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(mode == .logIn ? "Welcome back" : "Create your account")
                    .font(.title).fontWeight(.semibold)
                    .foregroundStyle(Palette.cream)
                Text(mode == .logIn
                     ? "Log in to keep your tasting log."
                     : "Start recording what you drink.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.muted)

                field("Email", text: $viewModel.email, key: "email")
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)

                if mode == .signUp {
                    field("Display name", text: $viewModel.displayName, key: "display_name")
                }

                secureField("Password", text: $viewModel.password, key: "password")

                // 入力欄に紐づかないエラー（認証失敗・通信断）はまとめてここに出す。
                if let error = viewModel.error, viewModel.fieldErrors.isEmpty {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(Palette.danger)
                }

                Button {
                    mode == .logIn ? viewModel.logIn() : viewModel.signUp()
                } label: {
                    Group {
                        if viewModel.isSubmitting {
                            ProgressView().tint(Color(hex: 0x241505))
                        } else {
                            Text(mode == .logIn ? "Log in" : "Sign up").fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(mode == .logIn ? !viewModel.canSubmitLogin : !viewModel.canSubmitSignUp)

                // 登録時にも法定年齢であることを明示する（初回起動の年齢確認に加えて）。
                if mode == .signUp {
                    Text("By signing up you confirm that you are of legal drinking age "
                         + "in the country where you live.")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                Button(mode == .logIn
                       ? "Don't have an account? Sign up"
                       : "Already have an account? Log in",
                       action: onSwitchMode)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .appBackground()
        .onChange(of: viewModel.isDone) { _, done in
            if done { onFinished() }
        }
    }

    private func field(_ label: String, text: Binding<String>, key: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
            if let message = viewModel.fieldErrors[key] {
                Text(message).font(.caption).foregroundStyle(Palette.danger)
            }
        }
    }

    private func secureField(_ label: String, text: Binding<String>, key: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SecureField(label, text: text)
                .textFieldStyle(.roundedBorder)
            if let message = viewModel.fieldErrors[key] {
                Text(message).font(.caption).foregroundStyle(Palette.danger)
            }
        }
    }
}
