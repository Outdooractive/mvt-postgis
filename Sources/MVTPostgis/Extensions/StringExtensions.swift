import Foundation

extension String {

    var isNotEmpty: Bool {
        !isEmpty
    }

    /// The string, or nil if it is empty
    var nilIfEmpty: String? {
        guard isNotEmpty else { return nil }
        return self
    }

    var toInt: Int? {
        Int(self)
    }

    var toDouble: Double? {
        return Double(self)
    }

}
