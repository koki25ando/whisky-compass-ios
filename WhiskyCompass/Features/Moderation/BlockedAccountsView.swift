import SwiftUI

@Observable
@MainActor
final class BlockedAccountsViewModel {
    var blocked: [BlockedUserDTO] = []
    var isLoading = true
    var error: String?

    private let repository = ModerationRepository.shared

    func load() {
        error = nil
        Task { @MainActor in
            do {
                blocked = try await repository.blockedUsers()
            } catch let apiError as APIError {
                error = apiError.message
            } catch {
                self.error = APIError.unknown.message
            }
            isLoading = false
        }
    }

    func unblock(_ user: BlockedUserDTO) {
        // 先に画面から消す。取り消しは軽い操作で、待たせる意味がないため。
        blocked.removeAll { $0.userId == user.userId }
        Task { @MainActor in
            do {
                try await repository.unblock(userId: user.userId)
            } catch {
                // 失敗したら元に戻す。消えたままだと「解除できた」と誤解される。
                load()
            }
        }
    }
}

/// ブロック中の相手の一覧と解除。
///
/// ブロックできるだけで解除できないと一方通行になるため、
/// マイページから必ず辿れるようにしてある。
struct BlockedAccountsView: View {
    @State private var viewModel = BlockedAccountsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.blocked.isEmpty {
                ErrorState(message: error) { viewModel.load() }
            } else if viewModel.blocked.isEmpty {
                EmptyHint(
                    title: "No blocked accounts",
                    message: "Blocked people's check-ins are hidden from your Home feed."
                )
            } else {
                List {
                    ForEach(viewModel.blocked) { user in
                        HStack(spacing: 12) {
                            Avatar(displayName: user.displayName, size: 36)
                            Text(user.displayName)
                                .font(.subheadline)
                                .foregroundStyle(Palette.cream)
                            Spacer()
                            Button("Unblock") { viewModel.unblock(user) }
                                .font(.caption)
                                .buttonStyle(.plain)
                                .foregroundStyle(Palette.gold)
                        }
                        .listRowBackground(Palette.surface)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .appBackground()
        .navigationTitle("Blocked accounts")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load() }
    }
}
