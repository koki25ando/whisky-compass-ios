import SwiftUI

struct CheckInCard: View {
    let checkIn: CheckInDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !checkIn.photos.isEmpty {
                PhotoCarousel(photos: checkIn.photos)
            }

            VStack(alignment: .leading, spacing: 10) {
                if !checkIn.note.isEmpty {
                    Text(checkIn.note)
                        .font(.subheadline)
                        .foregroundStyle(Palette.cream)
                        .lineLimit(3)
                }
                topFlavors
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .padding(.top, 16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Avatar(displayName: checkIn.user.displayName)

            VStack(alignment: .leading, spacing: 2) {
                Text(checkIn.whiskyName)
                    .font(.headline)
                    .foregroundStyle(Palette.cream)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
            RatingPill(rating: checkIn.rating)
        }
        .padding(.horizontal, 16)
    }

    private var subtitle: String {
        var parts = [checkIn.user.displayName]
        if let region = checkIn.whisky?.region, !region.isEmpty { parts.append(region) }
        parts.append(RelativeTime.relative(checkIn.drankAt))
        return parts.joined(separator: " · ")
    }

    /// フレーバーの強い上位2軸をタグで見せる。
    /// 一覧でレーダーを並べても読み取れないため、カードでは要約だけ出す。
    private var topFlavors: some View {
        let top = flavorAxes
            .compactMap { axis -> (FlavorAxis, Double)? in
                guard let value = checkIn.flavors[axis.key], value > 0 else { return nil }
                return (axis, value)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(2)

        return HStack(spacing: 6) {
            ForEach(Array(top), id: \.0.key) { axis, value in
                FlavorChip(label: "\(axis.short) \(Int(value))")
            }
        }
    }
}

/// Web版のscroll-snapカルーセルに相当。複数枚を横スワイプで見せる。
struct PhotoCarousel: View {
    let photos: [CheckInPhotoDTO]
    @State private var current = 0

    var body: some View {
        VStack(spacing: 8) {
            TabView(selection: $current) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    AsyncImage(url: URL(string: photo.url)) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Palette.surface2
                    }
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .aspectRatio(4.0 / 3.0, contentMode: .fit)

            if photos.count > 1 {
                PageDots(count: photos.count, current: current)
            }
        }
    }
}
