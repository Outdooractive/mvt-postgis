import Foundation
@testable import MVTPostgis
import Testing

struct ExtensionTests {

    // MARK: - Array

    @Test
    func `array is not empty`() {
        let empty: [Int] = []
        let nonEmpty = [1]
        #expect(empty.isNotEmpty == false)
        #expect(nonEmpty.isNotEmpty)
    }

    @Test
    func `array append if not nil`() {
        var array = [1]
        array.append(ifNotNil: 2)
        #expect(array == [1, 2])
        array.append(ifNotNil: nil)
        #expect(array == [1, 2])
    }

    @Test
    func `array remove`() {
        var array = [1, 2, 3, 2]
        array.remove(2)
        #expect(array == [1, 3])
    }

    // MARK: - Data

    @Test
    func `data UTF 8 string`() throws {
        let data = try #require("hello".data(using: .utf8))
        #expect(data.asUTF8EncodedString == "hello")
    }

    @Test
    func `data UTF 8 string invalid`() {
        let invalid = Data([0xFF, 0xFE])
        #expect(invalid.asUTF8EncodedString == nil)
    }

    // MARK: - Dictionary

    @Test
    func `dictionary has key`() {
        let dict = ["a": 1]
        #expect(dict.hasKey("a"))
        #expect(dict.hasKey("b") == false)
    }

    @Test
    func `dictionary is not empty`() {
        let empty: [String: Int] = [:]
        let nonEmpty = ["a": 1]
        #expect(empty.isNotEmpty == false)
        #expect(nonEmpty.isNotEmpty)
    }

    // MARK: - Double

    @Test
    func `double at least`() {
        #expect(5.0.atLeast(3.0) == 5.0)
        #expect(1.0.atLeast(3.0) == 3.0)
        #expect((-5.0).atLeast(0.0) == 0.0)
    }

    // MARK: - FloatingPoint

    @Test
    func `floating point round to places`() {
        #expect(3.14159.rounded(toPlaces: 2) == 3.14)
        #expect(3.14159.rounded(toPlaces: 0) == 3.0)
        #expect(3.14159.rounded(toPlaces: 4) == 3.1416)
    }

    @Test
    func `floating point mutating round`() {
        var value = 3.14159
        value.round(toPlaces: 2)
        #expect(value == 3.14)
    }

    // MARK: - Int

    @Test
    func `int at least`() {
        #expect(5.atLeast(3) == 5)
        #expect(1.atLeast(3) == 3)
        #expect((-5).atLeast(0) == 0)
    }

    // MARK: - String

    @Test
    func `string is not empty`() {
        #expect("".isNotEmpty == false)
        #expect("a".isNotEmpty)
    }

    @Test
    func `string nil if empty`() {
        #expect("".nilIfEmpty == nil)
        #expect("a".nilIfEmpty == "a")
    }

    @Test
    func `string to int`() {
        #expect("42".toInt == 42)
        #expect("abc".toInt == nil)
        #expect("".toInt == nil)
    }

    @Test
    func `string to double`() {
        #expect("3.14".toDouble == 3.14)
        #expect("abc".toDouble == nil)
    }

    // MARK: - ThreadSafeArrayCollector

    @Test
    func `thread safe array collector`() {
        let collector = ThreadSafeArrayCollector<Int>()
        #expect(collector.isEmpty)
        #expect(collector.items == [])

        collector.append(1)
        collector.append([2, 3])
        #expect(collector.count == 3)
        #expect(collector.items == [1, 2, 3])
    }

    @Test
    func `thread safe array collector with initial`() {
        let collector = ThreadSafeArrayCollector<Int>([1, 2])
        #expect(collector.count == 2)
        collector.append(3)
        #expect(collector.items == [1, 2, 3])
    }

    // MARK: - ThreadSafeObjectCollector

    @Test
    func `thread safe object collector`() {
        let collector = ThreadSafeObjectCollector<Int>(0)
        #expect(collector.item == 0)
        collector.set(42)
        #expect(collector.item == 42)
    }

}
