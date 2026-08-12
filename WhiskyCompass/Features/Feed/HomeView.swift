import SwiftUI

struct HomeView: View {
    let onOpenMyPage: () -> Void

    @State private var list = CheckInListViewModel(source: .feed)
    @State private var profile = ProfileViewModel()
    @State private var showingEditor = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content

            // ラベルは置かない。＋だけで意味は通るうえ、横長のボタンは
            // 一覧の写真に被る面積が大きく、画面がうるさくなる。
            Button {
                showingEditor = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x241505))
                    .frame(width: 56, height: 56)
                    .background(Palette.gold, in: Circle())
                    .shadow(radius: 6, y: 3)
            }
            .padding(20)
            .accessibilityLabel("New check-in")
        }
        .appBackground()
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // 右上はアカウントへの入口。ログアウトはマイページに置く。
                Button(action: onOpenMyPage) {
                    Avatar(displayName: profile.user?.displayName ?? "", size: 32)
                }
                .accessibilityLabel("My page")
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                CheckInEditorView(checkInId: nil) { showingEditor = false }
            }
        }
        .task {
            if list.isLoading { list.refresh() }
            // ホームでは統計を使わないので取りに行かない。
            profile.load(includeStats: false)
        }
    }

    @ViewBuilder
    private var content: some View {
        if list.isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if list.checkIns.isEmpty, let error = list.error {
            ErrorState(message: error) { list.refresh() }
        } else {
            CheckInList(
                viewModel: list,
                emptyTitle: "Nothing here yet",
                emptyBody: "Be the first to log a dram. Tap + to start."
            )
        }
    }
}

/// ホームとマイページで共通の一覧描画。
struct CheckInList: View {
    let viewModel: CheckInListViewModel
    let emptyTitle: String
    let emptyBody: String
    var header: AnyView? = nil

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if let header {
                    header
                }

                if viewModel.checkIns.isEmpty {
                    EmptyHint(title: emptyTitle, message: emptyBody)
                }

                ForEach(viewModel.checkIns) { checkIn in
                    NavigationLink(value: Route.checkIn(checkIn.checkInId)) {
                        CheckInCard(checkIn: checkIn)
                    }
                    .buttonStyle(.plain)
                    .onAppear { viewModel.loadMoreIfNeeded(currentItem: checkIn) }
                }

                if viewModel.isLoadingMore {
                    ProgressView().padding(16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 96)
        }
        // 引っ張って更新。自動再取得は記録の変更時にしか走らないため、
        // 他人の投稿を今すぐ見に行く手段として要る。
        .refreshable { viewModel.refresh() }
    }
}
