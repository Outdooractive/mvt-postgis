import Foundation

extension Int {

    func atLeast(_ minValue: Int) -> Int {
        Swift.max(minValue, self)
    }

}
