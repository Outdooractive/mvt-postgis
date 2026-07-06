import Collections
import Foundation
import Testing
@testable import MVTPostgis

struct ExtensionTests {

    // MARK: - Array

    @Test
    func arrayIsNotEmpty() {
        let empty: [Int] = []
        let nonEmpty = [1]
        #expect(empty.isNotEmpty == false)
        #expect(nonEmpty.isNotEmpty)
    }

    @Test
    func arrayAppendIfNotNil() {
        var array = [1]
        array.append(ifNotNil: 2)
        #expect(array == [1, 2])
        array.append(ifNotNil: nil)
        #expect(array == [1, 2])
    }

    @Test
    func arrayRemove() {
        var array = [1, 2, 3, 2]
        array.remove(2)
        #expect(array == [1, 3])
    }

    // MARK: - Data

    @Test
    func dataUTF8String() {
        let data = "hello".data(using: .utf8)!
        #expect(data.asUTF8EncodedString == "hello")
    }

    @Test
    func dataUTF8StringInvalid() {
        let invalid = Data([0xFF, 0xFE])
        #expect(invalid.asUTF8EncodedString == nil)
    }

    // MARK: - Deque

    @Test
    func dequeIsNotEmpty() {
        var deque = Deque<Int>()
        #expect(deque.isNotEmpty == false)
        deque.append(1)
        #expect(deque.isNotEmpty)
    }

    // MARK: - Dictionary

    @Test
    func dictionaryHasKey() {
        let dict = ["a": 1]
        #expect(dict.hasKey("a"))
        #expect(dict.hasKey("b") == false)
    }

    @Test
    func dictionaryIsNotEmpty() {
        let empty: [String: Int] = [:]
        let nonEmpty = ["a": 1]
        #expect(empty.isNotEmpty == false)
        #expect(nonEmpty.isNotEmpty)
    }

    // MARK: - Double

    @Test
    func doubleAtLeast() {
        #expect(5.0.atLeast(3.0) == 5.0)
        #expect(1.0.atLeast(3.0) == 3.0)
        #expect((-5.0).atLeast(0.0) == 0.0)
    }

    // MARK: - FloatingPoint

    @Test
    func floatingPointRoundToPlaces() {
        #expect(3.14159.rounded(toPlaces: 2) == 3.14)
        #expect(3.14159.rounded(toPlaces: 0) == 3.0)
        #expect(3.14159.rounded(toPlaces: 4) == 3.1416)
    }

    @Test
    func floatingPointMutatingRound() {
        var value = 3.14159
        value.round(toPlaces: 2)
        #expect(value == 3.14)
    }

    // MARK: - Int

    @Test
    func intAtLeast() {
        #expect(5.atLeast(3) == 5)
        #expect(1.atLeast(3) == 3)
        #expect((-5).atLeast(0) == 0)
    }

    // MARK: - String

    @Test
    func stringIsNotEmpty() {
        #expect("".isNotEmpty == false)
        #expect("a".isNotEmpty)
    }

    @Test
    func stringNilIfEmpty() {
        #expect("".nilIfEmpty == nil)
        #expect("a".nilIfEmpty == "a")
    }

    @Test
    func stringToInt() {
        #expect("42".toInt == 42)
        #expect("abc".toInt == nil)
        #expect("".toInt == nil)
    }

    @Test
    func stringToDouble() {
        #expect("3.14".toDouble == 3.14)
        #expect("abc".toDouble == nil)
    }

    // MARK: - ThreadSafeArrayCollector

    @Test
    func threadSafeArrayCollector() {
        let collector = ThreadSafeArrayCollector<Int>()
        #expect(collector.count == 0)
        #expect(collector.items == [])

        collector.append(1)
        collector.append([2, 3])
        #expect(collector.count == 3)
        #expect(collector.items == [1, 2, 3])
    }

    @Test
    func threadSafeArrayCollectorWithInitial() {
        let collector = ThreadSafeArrayCollector<Int>([1, 2])
        #expect(collector.count == 2)
        collector.append(3)
        #expect(collector.items == [1, 2, 3])
    }

    // MARK: - ThreadSafeObjectCollector

    @Test
    func threadSafeObjectCollector() {
        let collector = ThreadSafeObjectCollector<Int>(0)
        #expect(collector.item == 0)
        collector.set(42)
        #expect(collector.item == 42)
    }

}
