import Foundation

// MARK: ThreadSafeArrayCollector

public final class ThreadSafeArrayCollector<T>: @unchecked Sendable {

    private var array: [T]
    private let lock = NSLock()

    public init(_ initial: [T] = []) {
        array = initial
    }

    public func append(_ item: T) {
        lock.lock()
        defer { lock.unlock() }
        array.append(item)
    }

    public func append(_ items: [T]) {
        lock.lock()
        defer { lock.unlock() }
        array.append(contentsOf: items)
    }

    public var items: [T] {
        lock.lock()
        defer { lock.unlock() }
        return array
    }

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return array.count
    }

}

// MARK: - ThreadSafeObjectCollector

public final class ThreadSafeObjectCollector<T>: @unchecked Sendable {

    private var object: T
    private let lock = NSLock()

    public init(_ initial: T) {
        object = initial
    }

    public func set(_ item: T) {
        lock.lock()
        defer { lock.unlock() }
        object = item
    }

    public var item: T {
        lock.lock()
        defer { lock.unlock() }
        return object
    }

}
