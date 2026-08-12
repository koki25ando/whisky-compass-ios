import SwiftUI

/// 初回起動時の年齢確認。ログイン画面より前に出す。
///
/// ログイン画面の手前に置くことで、新規登録・ログインのどちらの経路でも
/// 必ず通る。一度確認すれば端末に記録され、再ログイン時には出ない。
struct AgeGateView: View {
    let onConfirmed: () -> Void

    @State private var declined = false

    private let minimumAge = AgeGate.minimumAge

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                icon

                if declined {
                    declinedContent
                } else {
                    questionContent
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            Text("Please enjoy responsibly.")
                .font(.caption)
                .foregroundStyle(Palette.muted)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
    }

    /// アイコンと同じ六角形。ブランドの一貫性のため。
    private var icon: some View {
        Image(systemName: "hexagon")
            .font(.system(size: 56, weight: .light))
            .foregroundStyle(Palette.gold)
    }

    private var questionContent: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Text("Whisky Compass")
                    .font(.title).fontWeight(.semibold)
                    .foregroundStyle(Palette.cream)
                Text("This app is about whisky, so it is only for people of legal drinking age.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button {
                    AgeGate.confirm()
                    onConfirmed()
                } label: {
                    Text("I am \(minimumAge) or older")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)

                Button("I am under \(minimumAge)") {
                    declined = true
                }
                .font(.subheadline)
                .foregroundStyle(Palette.muted)
            }
        }
    }

    /// 未成年と答えた場合。ここから先に進める導線は用意しない。
    private var declinedContent: some View {
        VStack(spacing: 10) {
            Text("Come back when you're \(minimumAge)")
                .font(.title2).fontWeight(.semibold)
                .foregroundStyle(Palette.cream)
                .multilineTextAlignment(.center)
            Text("You need to be \(minimumAge) or older to use Whisky Compass. We'll be here.")
                .font(.subheadline)
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
        }
    }
}
