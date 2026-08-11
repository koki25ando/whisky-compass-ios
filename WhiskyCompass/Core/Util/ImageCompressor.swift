import UIKit

/// 選んだ写真をアップロードできるJPEGバイト列にする。
///
/// サーバー側でも長辺1600pxのJPEGに正規化されるが、スマホの原寸写真（数MB）を
/// そのまま投げるとモバイル回線で数十秒かかり、タイムアウトにも近づく。送る前に縮める。
/// （Android版の ImageCompressor.kt と同じ方針・同じ上限）
enum ImageCompressor {

    private static let maxEdge: CGFloat = 2048
    private static let quality: CGFloat = 0.88

    static func jpegData(from image: UIImage) -> Data? {
        // UIImageは向き情報(imageOrientation)を別に持つ。描き直すことで
        // ピクセル自体を正しい向きにしてから書き出す（そうしないと横倒しになる）。
        let scaled = resized(image)
        return scaled.jpegData(compressionQuality: quality)
    }

    private static func resized(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        let ratio = longest > maxEdge ? maxEdge / longest : 1
        let target = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
