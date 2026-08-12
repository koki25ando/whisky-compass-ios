import SwiftUI

/// 記録を通報するシート。
///
/// App Reviewガイドライン1.2が求める通報導線。理由を選んで送るだけの構成にしてある。
/// 手数を増やすと通報されずに終わるため、任意の補足以外は聞かない。
struct ReportSheet: View {
    let checkInId: String
    let onFinished: (String) -> Void

    @State private var reason: ReportReason = .offensive
    @State private var note = ""
    @State private var isSending = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Why are you reporting this?") {
                    Picker("Reason", selection: $reason) {
                        ForEach(ReportReason.allCases) { reason in
                            Text(reason.label).tag(reason)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Anything else? (optional)") {
                    TextField("Add a note", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let error {
                    Section {
                        Text(error).font(.footnote).foregroundStyle(Palette.danger)
                    }
                }

                Section {
                    Text("We review reports and act on them within 24 hours.")
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Report check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send", action: send).disabled(isSending)
                }
            }
        }
        .tint(Palette.gold)
    }

    private func send() {
        isSending = true
        error = nil
        Task { @MainActor in
            do {
                try await ModerationRepository.shared.report(
                    checkInId: checkInId, reason: reason, note: note
                )
                dismiss()
                onFinished("Thanks. We'll take a look.")
            } catch let apiError as APIError {
                error = apiError.message
            } catch {
                self.error = APIError.unknown.message
            }
            isSending = false
        }
    }
}
