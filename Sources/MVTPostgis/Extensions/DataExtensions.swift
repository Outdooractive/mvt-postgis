import Foundation

extension Data {

    var asUTF8EncodedString: String? {
        String(data: self, encoding: .utf8)
    }

}
