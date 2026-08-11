import SwiftUI

/// フレーバー6軸のレーダーチャート。
///
/// Web版はChart.jsを使っているが、6軸固定の六角形はSwiftUIのCanvasに直接描くほうが
/// 軽く、スライダーの再描画とも素直に噛み合う（Android版でも同じ判断をしている）。
/// 入力は0〜10のUIスケール。
struct FlavorRadar: View {
    /// 軸キー → 0〜10の値。
    let values: [String: Double]
    var maxValue: Double = 10

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            // ラベルを外周に置くぶん、チャート本体は少し内側に描く。
            let radius = min(size.width, size.height) / 2 * 0.66

            drawGrid(context: context, center: center, radius: radius)
            drawAxes(context: context, center: center, radius: radius)
            drawValues(context: context, center: center, radius: radius)
            drawLabels(context: context, center: center, radius: radius)
        }
        .aspectRatio(1.15, contentMode: .fit)
    }

    // MARK: - 描画

    private func vertex(center: CGPoint, radius: CGFloat, index: Int) -> CGPoint {
        // 12時方向を起点に時計回り。Web版・Android版と同じ並びにする。
        let angle = -Double.pi / 2 + 2 * Double.pi * Double(index) / Double(flavorAxes.count)
        return CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }

    private func polygon(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for index in flavorAxes.indices {
            let point = vertex(center: center, radius: radius, index: index)
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    private func drawGrid(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        // 25%刻みの目盛り。数値軸を書かなくても濃淡の目安になる。
        for scale in [0.25, 0.5, 0.75, 1.0] {
            context.stroke(
                polygon(center: center, radius: radius * scale),
                with: .color(Palette.line),
                lineWidth: scale == 1.0 ? 1.5 : 1
            )
        }
    }

    private func drawAxes(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        for index in flavorAxes.indices {
            var path = Path()
            path.move(to: center)
            path.addLine(to: vertex(center: center, radius: radius, index: index))
            context.stroke(path, with: .color(Palette.line), lineWidth: 1)
        }
    }

    private func drawValues(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        var path = Path()
        for (index, axis) in flavorAxes.enumerated() {
            let ratio = min(max((values[axis.key] ?? 0) / maxValue, 0), 1)
            let point = vertex(center: center, radius: radius * ratio, index: index)
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()

        context.fill(path, with: .color(Palette.gold.opacity(0.28)))
        context.stroke(path, with: .color(Palette.gold), lineWidth: 2)

        for (index, axis) in flavorAxes.enumerated() {
            let ratio = min(max((values[axis.key] ?? 0) / maxValue, 0), 1)
            let point = vertex(center: center, radius: radius * ratio, index: index)
            let dot = Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6))
            context.fill(dot, with: .color(Palette.goldSoft))
        }
    }

    private func drawLabels(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        for (index, axis) in flavorAxes.enumerated() {
            let point = vertex(center: center, radius: radius * 1.26, index: index)
            let text = Text(axis.short)
                .font(.system(size: 11))
                .foregroundColor(Palette.muted)
            context.draw(context.resolve(text), at: point, anchor: .center)
        }
    }
}
