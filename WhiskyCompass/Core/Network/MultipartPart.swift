import Foundation

/// multipart/form-data の1パート。
///
/// 同じ名前のパートを繰り返すと配列になる（DRFのListFieldが`getlist`で受ける）。
/// 写真の複数枚送信とフレーバー軸の送信は、どちらもこの性質に乗っている。
struct MultipartPart {
    let name: String
    let filename: String?
    let contentType: String?
    let data: Data

    static func text(_ name: String, _ value: String) -> MultipartPart {
        MultipartPart(name: name, filename: nil, contentType: nil, data: Data(value.utf8))
    }

    static func jpeg(_ name: String, filename: String, data: Data) -> MultipartPart {
        MultipartPart(name: name, filename: filename, contentType: "image/jpeg", data: data)
    }

    static func body(parts: [MultipartPart], boundary: String) -> Data {
        var body = Data()
        for part in parts {
            body.append("--\(boundary)\r\n")
            if let filename = part.filename {
                body.append(
                    "Content-Disposition: form-data; name=\"\(part.name)\"; filename=\"\(filename)\"\r\n"
                )
            } else {
                body.append("Content-Disposition: form-data; name=\"\(part.name)\"\r\n")
            }
            if let contentType = part.contentType {
                body.append("Content-Type: \(contentType)\r\n")
            }
            body.append("\r\n")
            body.append(part.data)
            body.append("\r\n")
        }
        body.append("--\(boundary)--\r\n")
        return body
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
