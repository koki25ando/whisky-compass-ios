import PhotosUI
import SwiftUI

@Observable
@MainActor
final class EditorViewModel {

    var draft = CheckInDraft()
    var existingPhotos: [CheckInPhotoDTO] = []
    var suggestions: [WhiskyDTO] = []
    var isLoading = false
    var isSaving = false
    var error: String?
    var fieldErrors: [String: String] = [:]
    var savedId: String?

    private let repository = CheckInRepository.shared
    private var suggestionTask: Task<Void, Never>?

    var isEditing: Bool { draft.checkInId != nil }

    var visibleExistingPhotos: [CheckInPhotoDTO] {
        existingPhotos.filter { !draft.removedPhotoIds.contains($0.checkInPhotoId) }
    }

    var photoCount: Int { visibleExistingPhotos.count + draft.newPhotos.count }

    var canAddPhotos: Bool { photoCount < maxPhotosPerCheckIn }

    var canSave: Bool {
        !draft.whiskyName.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving && !isLoading
    }

    /// 戻るときに「捨てていいか」を聞くべきか。
    var hasUnsavedInput: Bool {
        guard savedId == nil, !isSaving else { return false }
        return !draft.whiskyName.isEmpty || !draft.note.isEmpty
            || !draft.newPhotos.isEmpty || !draft.removedPhotoIds.isEmpty
    }

    init(checkInId: String?) {
        draft.checkInId = checkInId
        if let checkInId { load(checkInId) }
    }

    private func load(_ id: String) {
        isLoading = true
        Task { @MainActor in
            do {
                let checkIn = try await repository.checkIn(id: id)
                draft.whiskyName = checkIn.whiskyName
                draft.rating = checkIn.rating
                draft.note = checkIn.note
                draft.drankAt = RelativeTime.parse(checkIn.drankAt)
                // 既にスコアがある記録だけ、開いたときONで復元する。
                draft.recordFlavors = !checkIn.flavors.isEmpty
                for axis in flavorAxes {
                    draft.flavors[axis.key] = Int(checkIn.flavors[axis.key] ?? 0)
                }
                existingPhotos = checkIn.photos
            } catch let apiError as APIError {
                error = apiError.message
            } catch {
                self.error = APIError.unknown.message
            }
            isLoading = false
        }
    }

    /// 1文字ごとに投げると打鍵のたびにリクエストが飛ぶので少し待つ。
    func onWhiskyNameChanged() {
        error = nil
        fieldErrors = [:]
        suggestionTask?.cancel()

        let query = draft.whiskyName
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            suggestions = []
            return
        }
        suggestionTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            suggestions = (try? await repository.searchWhiskies(query: query)) ?? []
        }
    }

    func pick(_ whisky: WhiskyDTO) {
        draft.whiskyName = whisky.name
        suggestions = []
    }

    func addPhotos(_ items: [Data]) {
        let room = max(0, maxPhotosPerCheckIn - photoCount)
        draft.newPhotos.append(contentsOf: items.prefix(room))
    }

    func removeNewPhoto(at index: Int) {
        guard draft.newPhotos.indices.contains(index) else { return }
        draft.newPhotos.remove(at: index)
    }

    func removeExistingPhoto(_ id: String) {
        draft.removedPhotoIds.append(id)
    }

    func save() {
        guard canSave else { return }
        isSaving = true
        error = nil
        fieldErrors = [:]

        Task { @MainActor in
            do {
                let saved = try await repository.save(draft)
                isSaving = false
                savedId = saved.checkInId
            } catch let apiError as APIError {
                // 保存に失敗しても入力内容は捨てない。再送できる状態で止める。
                isSaving = false
                error = apiError.message
                fieldErrors = apiError.fieldErrors
            } catch {
                isSaving = false
                self.error = APIError.unknown.message
            }
        }
    }
}

struct CheckInEditorView: View {
    let checkInId: String?
    let onFinished: () -> Void

    @State private var viewModel: EditorViewModel
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var confirmingDiscard = false
    @Environment(\.dismiss) private var dismiss

    init(checkInId: String?, onFinished: @escaping () -> Void) {
        self.checkInId = checkInId
        self.onFinished = onFinished
        _viewModel = State(initialValue: EditorViewModel(checkInId: checkInId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                form
            }
        }
        .appBackground()
        .navigationTitle(viewModel.isEditing ? "Edit check-in" : "New check-in")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    // 入力途中に戻ると内容が黙って消えるため、捨てていいか一度聞く。
                    if viewModel.hasUnsavedInput { confirmingDiscard = true } else { onFinished() }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.save()
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Text("Save").fontWeight(.semibold)
                    }
                }
                .disabled(!viewModel.canSave)
            }
        }
        .alert("Discard this check-in?", isPresented: $confirmingDiscard) {
            Button("Keep editing", role: .cancel) {}
            Button("Discard", role: .destructive) { onFinished() }
        } message: {
            Text("Your input hasn't been saved yet.")
        }
        .onChange(of: viewModel.savedId) { _, saved in
            if saved != nil { onFinished() }
        }
        .onChange(of: photoItems) { _, items in
            loadPickedPhotos(items)
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                whiskyField
                ratingPicker
                drankAtPicker
                photoPicker
                noteField
                flavorSection

                if let error = viewModel.error {
                    Text(error).font(.subheadline).foregroundStyle(Palette.danger)
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
    }

    private var whiskyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Whisky").font(.headline).foregroundStyle(Palette.cream)
            TextField("e.g. Lagavulin 16 Year", text: Binding(
                get: { viewModel.draft.whiskyName },
                set: {
                    viewModel.draft.whiskyName = $0
                    viewModel.onWhiskyNameChanged()
                }
            ))
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()

            if let message = viewModel.fieldErrors["whisky_name"] {
                Text(message).font(.caption).foregroundStyle(Palette.danger)
            }

            // Web版の<datalist>に相当。一致がなければサーバー側で新規銘柄が作られる。
            if !viewModel.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.suggestions.prefix(5)) { whisky in
                        Button {
                            viewModel.pick(whisky)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(whisky.name)
                                    .font(.subheadline).foregroundStyle(Palette.cream)
                                let meta = [whisky.distilleryName, whisky.region]
                                    .filter { !$0.isEmpty }.joined(separator: " · ")
                                if !meta.isEmpty {
                                    Text(meta).font(.caption).foregroundStyle(Palette.muted)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var ratingPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Rating").font(.headline).foregroundStyle(Palette.cream)
                Text("\(viewModel.draft.rating) / 10")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
            // Web版と同じくタップで選ぶ★10段階。
            HStack(spacing: 2) {
                ForEach(1...10, id: \.self) { value in
                    Button {
                        viewModel.draft.rating = value
                    } label: {
                        Image(systemName: "star.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(value <= viewModel.draft.rating
                                             ? Palette.gold : Palette.line)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Rate \(value)")
                }
            }
        }
    }

    /// 既定は「今」だが、昨日飲んだものを今日書けるように後から変えられる。
    private var drankAtPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("When").font(.headline).foregroundStyle(Palette.cream)
            DatePicker(
                "Drank at",
                selection: Binding(
                    get: { viewModel.draft.drankAt ?? Date() },
                    set: { viewModel.draft.drankAt = $0 }
                ),
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .labelsHidden()

            if viewModel.draft.drankAt == nil {
                Text("Defaults to now — change it to log something you drank earlier.")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }
    }

    private var photoPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Photos").font(.headline).foregroundStyle(Palette.cream)
                Text("\(viewModel.photoCount)").font(.caption).foregroundStyle(Palette.muted)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.visibleExistingPhotos) { photo in
                        thumbnail {
                            AsyncImage(url: URL(string: photo.url)) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: { Palette.surface2 }
                        } onRemove: {
                            viewModel.removeExistingPhoto(photo.checkInPhotoId)
                        }
                    }

                    ForEach(Array(viewModel.draft.newPhotos.enumerated()), id: \.offset) { index, data in
                        thumbnail {
                            if let image = UIImage(data: data) {
                                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Palette.surface2
                            }
                        } onRemove: {
                            viewModel.removeNewPhoto(at: index)
                        }
                    }

                    if viewModel.canAddPhotos {
                        // 写真ピッカーはフォトライブラリ全体への許可を要求しない。
                        PhotosPicker(
                            selection: $photoItems,
                            maxSelectionCount: maxPhotosPerCheckIn,
                            matching: .images
                        ) {
                            Image(systemName: "plus")
                                .foregroundStyle(Palette.muted)
                                .frame(width: 96, height: 96)
                                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
    }

    private func thumbnail<Content: View>(
        @ViewBuilder content: () -> Content,
        onRemove: @escaping () -> Void
    ) -> some View {
        content()
            .frame(width: 96, height: 96)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topTrailing) {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.cream)
                        .padding(5)
                        .background(Palette.bgDeep, in: Circle())
                }
                .padding(4)
                .accessibilityLabel("Remove photo")
            }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tasting note").font(.headline).foregroundStyle(Palette.cream)
            Text("What did it smell and taste like? Your own words are the point.")
                .font(.caption).foregroundStyle(Palette.muted)
            TextEditor(text: $viewModel.draft.note)
                .frame(minHeight: 110)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(Palette.cream)
        }
    }

    private var flavorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Flavor profile").font(.headline).foregroundStyle(Palette.cream)

            // 明示的にONにされたときだけ保存する。触っていないスライダーの初期値5を
            // 保存すると、フレーバーデータ（プロダクトの資産）に中央値が混ざり続ける。
            Toggle(isOn: $viewModel.draft.recordFlavors) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Record a flavor profile")
                        .font(.subheadline).foregroundStyle(Palette.cream)
                    Text("Leave this off unless you actually want to score the six axes.")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
            }
            .padding(14)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))

            if viewModel.draft.recordFlavors {
                // スライダーを動かすとレーダーが即座に変形する（Web版と同じ体験）。
                FlavorRadar(values: viewModel.draft.flavors.mapValues(Double.init))

                ForEach(flavorAxes) { axis in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(axis.label).font(.subheadline).foregroundStyle(Palette.cream)
                            Spacer()
                            Text("\(viewModel.draft.flavors[axis.key] ?? 0)")
                                .font(.caption).foregroundStyle(Palette.muted)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.draft.flavors[axis.key] ?? 0) },
                                set: { viewModel.draft.flavors[axis.key] = Int($0.rounded()) }
                            ),
                            in: 0...10,
                            step: 1
                        )
                    }
                }
            }
        }
    }

    private func loadPickedPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task { @MainActor in
            var compressed: [Data] = []
            for item in items {
                guard let raw = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: raw),
                      let jpeg = ImageCompressor.jpegData(from: image)
                else { continue }
                compressed.append(jpeg)
            }
            viewModel.addPhotos(compressed)
            photoItems = []
        }
    }
}
