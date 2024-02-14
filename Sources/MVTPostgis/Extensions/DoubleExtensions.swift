import Foundation

extension Double {

    func atLeast(_ minValue: Double) -> Double {
        Swift.max(minValue, self)
    }

}
