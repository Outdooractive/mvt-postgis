import Foundation

extension Dictionary {

    func hasKey(_ key: Key) -> Bool {
        self[key] != nil
    }

    var isNotEmpty: Bool {
        isEmpty == false
    }

}
