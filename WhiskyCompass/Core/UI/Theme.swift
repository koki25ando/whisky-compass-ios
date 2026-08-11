import SwiftUI

/// Web版の配色（whisky-compass-web/static/css の :root 変数）をそのまま持ち込む。
/// Android版とも同じ値。プラットフォームごとに見た目が変わると同じプロダクトに見えない。
enum Palette {
    static let bgDeep = Color(hex: 0x0D0B08)
    static let bgRaised = Color(hex: 0x16110D)
    static let surface = Color(hex: 0x241C15)
    static let surface2 = Color(hex: 0x2F251B)
    static let line = Color(hex: 0x3D2F20)
    static let gold = Color(hex: 0xC99A44)
    static let goldSoft = Color(hex: 0xE4C176)
    static let plum = Color(hex: 0x8C3E52)
    static let cream = Color(hex: 0xF3E9D6)
    static let muted = Color(hex: 0x9C8F7C)
    static let danger = Color(hex: 0xE08A8A)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// 画面全体の下地。Web/Androidと同じくダーク固定。
struct AppBackground: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            Palette.bgDeep.ignoresSafeArea()
            content
        }
        .tint(Palette.gold)
    }
}

extension View {
    func appBackground() -> some View { modifier(AppBackground()) }
}
