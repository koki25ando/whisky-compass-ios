import SwiftUI

@Observable
@MainActor
final class WhiskyDetailViewModel {
    var whisky: WhiskyDetailDTO?
    var notes: [CheckInDTO] = []
    var isLoading = true
    var error: String?

    private let repository = CheckInRepository.shared
    private let whiskyId: String

    init(whiskyId: String) {
        self.whiskyId = whiskyId
    }

    func load() {
        isLoading = whisky == nil
        error = nil
        Task { @MainActor in
            do {
                whisky = try await repository.whisky(id: whiskyId)
            } catch let apiError as APIError {
                error = apiError.message
            } catch {
                self.error = APIError.unknown.message
            }
            // ノート一覧が取れなくても集計は見せたいので、失敗は握り潰す。
            notes = (try? await repository.whiskyCheckIns(id: whiskyId))?.results ?? []
            isLoading = false
        }
    }
}

/// 銘柄1本のページ。
///
/// フィードは流れて消えるが、ここには銘柄ごとに記録が積み上がる。
/// 溜めたデータがユーザーから見える唯一の場所（docs/00-north-star.md フェーズ2 / F-05）。
struct WhiskyDetailView: View {
    let whiskyId: String

    @State private var viewModel: WhiskyDetailViewModel

    init(whiskyId: String) {
        self.whiskyId = whiskyId
        _viewModel = State(initialValue: WhiskyDetailViewModel(whiskyId: whiskyId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let whisky = viewModel.whisky {
                content(whisky)
            } else {
                ErrorState(message: viewModel.error ?? "") { viewModel.load() }
            }
        }
        .appBackground()
        .navigationTitle("Whisky")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load() }
    }

    private func content(_ whisky: WhiskyDetailDTO) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(whisky.name)
                        .font(.title2).fontWeight(.semibold)
                        .foregroundStyle(Palette.cream)
                    let meta = [
                        whisky.distilleryName.isEmpty ? nil : whisky.distilleryName,
                        whisky.region.isEmpty ? nil : whisky.region,
                        whisky.ageStatement.map { "\($0) years" },
                        whisky.abv.map { "\($0)% ABV" },
                    ].compactMap { $0 }.joined(separator: " · ")
                    if !meta.isEmpty {
                        Text(meta).font(.subheadline).foregroundStyle(Palette.muted)
                    }
                }

                HStack(spacing: 10) {
                    StatTile(label: "Check-ins", value: "\(whisky.summary.total)")
                    StatTile(
                        label: "Avg rating",
                        value: whisky.summary.avgRating.map { String(format: "%.1f", $0) } ?? "–"
                    )
                    StatTile(label: "Flavor profiles", value: "\(whisky.summary.flavorCount)")
                }

                communityFlavor(whisky.summary)
                notesSection
            }
            .padding(16)
            .padding(.bottom, 32)
        }
    }

    private func communityFlavor(_ summary: WhiskySummaryDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Community flavor profile").font(.headline).foregroundStyle(Palette.cream)

            if summary.flavors.isEmpty {
                Text("No flavor profiles recorded for this whisky yet.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            } else {
                Text("Averaged from \(summary.flavorCount) tasting(s).")
                    .font(.caption).foregroundStyle(Palette.muted)
                FlavorRadar(values: summary.flavors)
                    .padding(12)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tasting notes").font(.headline).foregroundStyle(Palette.cream)

            if viewModel.notes.isEmpty {
                Text("No one has written a note about this whisky yet.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            } else {
                ForEach(viewModel.notes) { note in
                    NavigationLink(value: Route.checkIn(note.checkInId)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Avatar(displayName: note.user.displayName, size: 24)
                                VStack(alignment: .leading) {
                                    Text(note.user.displayName)
                                        .font(.caption).foregroundStyle(Palette.cream)
                                    Text(RelativeTime.relative(note.drankAt))
                                        .font(.caption).foregroundStyle(Palette.muted)
                                }
                                Spacer()
                                RatingPill(rating: note.rating)
                            }
                            Text(note.note)
                                .font(.subheadline)
                                .foregroundStyle(Palette.cream)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(14)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
