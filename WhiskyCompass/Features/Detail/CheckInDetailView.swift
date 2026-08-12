import SwiftUI

@Observable
@MainActor
final class CheckInDetailViewModel {
    var checkIn: CheckInDTO?
    var isLoading = true
    var error: String?
    var isDeleted = false
    var isBlocked = false

    private let repository = CheckInRepository.shared
    private let moderation = ModerationRepository.shared
    private let checkInId: String

    init(checkInId: String) {
        self.checkInId = checkInId
    }

    func load() {
        isLoading = checkIn == nil
        error = nil
        Task { @MainActor in
            do {
                checkIn = try await repository.checkIn(id: checkInId)
            } catch let apiError as APIError {
                error = apiError.message
            } catch {
                self.error = APIError.unknown.message
            }
            isLoading = false
        }
    }

    /// この記録の投稿者をブロックする。ブロック後はフィードからも詳細からも消える。
    func blockAuthor() {
        guard let userId = checkIn?.user.userId else { return }
        Task { @MainActor in
            do {
                try await moderation.block(userId: userId)
                isBlocked = true
            } catch let apiError as APIError {
                error = apiError.message
            } catch {
                self.error = APIError.unknown.message
            }
        }
    }

    func delete() {
        Task { @MainActor in
            do {
                try await repository.delete(id: checkInId)
                isDeleted = true
            } catch let apiError as APIError {
                error = apiError.message
            } catch {
                self.error = APIError.unknown.message
            }
        }
    }
}

struct CheckInDetailView: View {
    let checkInId: String

    @State private var viewModel: CheckInDetailViewModel
    @State private var confirmingDelete = false
    @State private var editing = false
    @State private var zoomedURL: String?
    @State private var reporting = false
    @State private var confirmingBlock = false
    @State private var toast: String?
    @Environment(\.dismiss) private var dismiss

    init(checkInId: String) {
        self.checkInId = checkInId
        _viewModel = State(initialValue: CheckInDetailViewModel(checkInId: checkInId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let checkIn = viewModel.checkIn {
                content(checkIn)
            } else {
                ErrorState(message: viewModel.error ?? "") { viewModel.load() }
            }
        }
        .appBackground()
        .navigationTitle("Check-in")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 編集・削除は所有者にだけ出す。URLを直接叩かれてもサーバーが404を返すので、
            // これは導線の話。
            if viewModel.checkIn?.isMine == true {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editing = true } label: { Image(systemName: "pencil") }
                        .accessibilityLabel("Edit")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { confirmingDelete = true } label: { Image(systemName: "trash") }
                        .accessibilityLabel("Delete")
                }
            } else if viewModel.checkIn != nil {
                // 他人の記録には通報とブロックを出す（App Reviewガイドライン1.2）。
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Report this check-in", systemImage: "flag") { reporting = true }
                        Button("Block this person", systemImage: "hand.raised", role: .destructive) {
                            confirmingBlock = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More")
                }
            }
        }
        .alert("Delete this check-in?", isPresented: $confirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { viewModel.delete() }
        } message: {
            Text("This can't be undone.")
        }
        .alert("Block this person?", isPresented: $confirmingBlock) {
            Button("Cancel", role: .cancel) {}
            Button("Block", role: .destructive) { viewModel.blockAuthor() }
        } message: {
            Text("You won't see their check-ins anymore. They aren't told about this. You can undo it from My page.")
        }
        .sheet(isPresented: $reporting) {
            ReportSheet(checkInId: checkInId) { message in toast = message }
        }
        .alert("Reported", isPresented: Binding(get: { toast != nil }, set: { if !$0 { toast = nil } })) {
            Button("OK") { toast = nil }
        } message: {
            Text(toast ?? "")
        }
        .onChange(of: viewModel.isBlocked) { _, blocked in
            // ブロックしたら相手の記録はもう見えない。開いたままにせず前の画面へ戻す。
            if blocked { dismiss() }
        }
        .sheet(isPresented: $editing) {
            NavigationStack {
                CheckInEditorView(checkInId: checkInId) {
                    editing = false
                    viewModel.load()
                }
            }
        }
        .fullScreenCover(item: Binding(
            get: { zoomedURL.map(IdentifiableURL.init) },
            set: { zoomedURL = $0?.value }
        )) { item in
            FullScreenPhoto(url: item.value) { zoomedURL = nil }
        }
        .onChange(of: viewModel.isDeleted) { _, deleted in
            if deleted { dismiss() }
        }
        .task { viewModel.load() }
    }

    private func content(_ checkIn: CheckInDTO) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 銘柄名から銘柄ページへ。ここが「溜まったデータ」への入口になる。
                if let whisky = checkIn.whisky {
                    NavigationLink(value: Route.whisky(whisky.whiskyId)) {
                        titleBlock(checkIn, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                } else {
                    titleBlock(checkIn, showsChevron: false)
                }

                HStack(spacing: 10) {
                    Avatar(displayName: checkIn.user.displayName, size: 28)
                    VStack(alignment: .leading) {
                        Text(checkIn.user.displayName)
                            .font(.subheadline).foregroundStyle(Palette.cream)
                        Text(RelativeTime.absolute(checkIn.drankAt))
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    RatingPill(rating: checkIn.rating)
                }

                if !checkIn.photos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(checkIn.photos) { photo in
                                AsyncImage(url: URL(string: photo.url)) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Palette.surface2
                                }
                                .frame(width: 280, height: 210)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .onTapGesture { zoomedURL = photo.url }
                            }
                        }
                    }
                }

                if !checkIn.note.isEmpty {
                    Text(checkIn.note)
                        .font(.body)
                        .foregroundStyle(Palette.cream)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
                }

                if !checkIn.flavors.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Flavor profile").font(.headline).foregroundStyle(Palette.cream)
                        FlavorRadar(values: checkIn.flavors)
                    }
                    .padding(16)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(16)
        }
    }

    private func titleBlock(_ checkIn: CheckInDTO, showsChevron: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(checkIn.whiskyName)
                    .font(.title2).fontWeight(.semibold)
                    .foregroundStyle(Palette.cream)
                if showsChevron {
                    Image(systemName: "chevron.right").foregroundStyle(Palette.muted)
                }
            }
            let subtitle = [checkIn.whisky?.distilleryName, checkIn.whisky?.region]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            if !subtitle.isEmpty {
                Text(subtitle).font(.subheadline).foregroundStyle(Palette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 写真を全画面で見る。カード内の切り抜きでは細部が分からないため。
struct FullScreenPhoto: View {
    let url: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            AsyncImage(url: URL(string: url)) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.white)
                    .padding(12)
            }
            .padding(8)
        }
        .onTapGesture(perform: onDismiss)
    }
}

/// `fullScreenCover(item:)` に文字列を渡すためのラッパー。
struct IdentifiableURL: Identifiable {
    let value: String
    var id: String { value }
}
