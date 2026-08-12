import SwiftUI

struct MyPageView: View {
    let onLoggedOut: () -> Void

    @State private var list = CheckInListViewModel(source: .mine)
    @State private var profile = ProfileViewModel()
    @State private var confirmingLogOut = false
    @State private var deletingAccount = false
    @State private var password = ""

    var body: some View {
        Group {
            if list.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if list.checkIns.isEmpty, let error = list.error {
                ErrorState(message: error) { list.refresh() }
            } else {
                CheckInList(
                    viewModel: list,
                    emptyTitle: "No check-ins yet",
                    emptyBody: "Your own records will show up here once you log one.",
                    header: AnyView(profileHeader)
                )
            }
        }
        .appBackground()
        .navigationTitle("My page")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { confirmingLogOut = true } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
                .accessibilityLabel("Log out")
            }
        }
        .alert("Log out?", isPresented: $confirmingLogOut) {
            Button("Cancel", role: .cancel) {}
            Button("Log out", role: .destructive) { profile.logOut() }
        } message: {
            Text("You will need your email and password to get back in.")
        }
        .alert("Delete your account?", isPresented: $deletingAccount) {
            SecureField("Password", text: $password)
            Button("Cancel", role: .cancel) { password = "" }
            Button("Delete account", role: .destructive) {
                profile.deleteAccount(password: password)
                password = ""
            }
        } message: {
            Text(
                profile.deleteError
                ?? """
                This permanently deletes your account, every check-in you have written, \
                all of your photos and your flavor profiles. It cannot be undone. \
                Enter your password to confirm.
                """
            )
        }
        .onChange(of: profile.loggedOut) { _, loggedOut in
            if loggedOut { onLoggedOut() }
        }
        .onChange(of: profile.deleteError) { _, error in
            // パスワード違いなどで失敗したら、もう一度入力できるように開き直す。
            if error != nil { deletingAccount = true }
        }
        .task {
            if list.isLoading { list.refresh() }
            profile.load()
        }
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Avatar(displayName: profile.user?.displayName ?? "", size: 56)
                VStack(alignment: .leading) {
                    Text(profile.user?.displayName ?? "")
                        .font(.title2).fontWeight(.semibold)
                        .foregroundStyle(Palette.cream)
                    Text(profile.user?.email ?? "")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                StatTile(label: "Total", value: profile.stats.map { "\($0.total)" } ?? "–")
                StatTile(label: "This month", value: profile.stats.map { "\($0.thisMonth)" } ?? "–")
                StatTile(
                    label: "Avg rating",
                    value: profile.stats?.avgRating.map { String(format: "%.1f", $0) } ?? "–"
                )
            }

            // アカウント削除の導線。App Store も Google Play も「アプリ内から削除できること」を
            // 必須にしているため、埋もれた場所ではなくプロフィール直下に置く。
            Button {
                profile.deleteError = nil
                deletingAccount = true
            } label: {
                // role: .destructive の既定色はiOSの赤で、Web/Android版の
                // 警告色（#E08A8A）から浮くため自前で指定する。
                Text("Delete account")
                    .font(.caption)
                    .foregroundStyle(Palette.danger)
            }
        }
        .padding(.bottom, 8)
    }
}
