import Foundation

extension Array {

    var isNotEmpty: Bool {
        !isEmpty
    }

    /// Adds a new element at the end of the array, if it's not nil.
    mutating func append(ifNotNil newElement: Element?) {
        guard let element = newElement else { return }
        append(element)
    }

}

extension Array where Element: Equatable {

    /// Removes all occurrences of the given object
    mutating func remove(_ element: Element) {
        self = filter { $0 != element }
    }

}
