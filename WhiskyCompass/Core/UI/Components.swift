import SwiftUI

/// ユーザーのイニシャル丸アイコン。Web/Android版と同じ表現。
struct Avatar: View {
    let displayName: String
    var size: CGFloat = 32

    var body: some View {
        Circle()
            .fill(Palette.surface2)
            .overlay(Circle().stroke(Palette.line, lineWidth: 1))
            .overlay(
                Text(initial)
                    .font(.system(size: size / 2.4, weight: .semibold))
                    .foregroundStyle(Palette.goldSoft)
            )
            .frame(width: size, height: size)
    }

    private var initial: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "?" : String(trimmed.prefix(1)).uppercased()
    }
}

/// 評価の表示。10段階を★10個並べると数を数える羽目になるので、
/// 星ひとつ＋数値で「9 / 10」と読ませる（Android版と同じ判断）。
struct RatingPill: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 11))
                .foregroundStyle(Palette.gold)
            Text("\(rating)")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(Palette.cream)
            Text("/ 10")
                .font(.caption)
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Palette.surface2, in: Capsule())
    }
}

/// フレーバーの上位軸などを示す小さなタグ。
struct FlavorChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption)
            .foregroundStyle(Palette.goldSoft)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Palette.surface2, in: Capsule())
            .overlay(Capsule().stroke(Palette.line, lineWidth: 1))
    }
}

/// 統計タイル（マイページ・銘柄ページで共通）。
struct StatTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2).fontWeight(.bold)
                .foregroundStyle(Palette.cream)
            Text(label)
                .font(.caption)
                .foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// 取得に失敗したときの再試行導線。
struct ErrorState: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(message)
                .foregroundStyle(Palette.danger)
                .multilineTextAlignment(.center)
            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}

/// 一覧が空のときの案内。
struct EmptyHint: View {
    let title: String
    let body: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.headline).foregroundStyle(Palette.cream)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}

/// 写真が複数枚あるときの位置インジケータ。
struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? Palette.gold : Palette.line)
                    .frame(width: index == current ? 7 : 5, height: index == current ? 7 : 5)
            }
        }
    }
}
