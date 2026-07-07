import Foundation

// MARK: ThreadSafeArrayCollector

/// A thread-safe array that can be read and written from multiple concurrent tasks.
///
/// Uses an ``NSLock`` internally to synchronize access. Marked `@unchecked Sendable`
/// because the lock guarantees thread safety despite the class containing mutable state.
public final class ThreadSafeArrayCollector<T>: @unchecked Sendable {

    private var array: [T]
    private let lock = NSLock()

    /// Creates a collector, optionally seeded with initial values.
    /// - Parameter initial: The initial array contents.
    public init(_ initial: [T] = []) {
        array = initial
    }

    /// Appends a single element.
    /// - Parameter item: The element to append.
    public func append(_ item: T) {
        lock.lock()
        defer { lock.unlock() }
        array.append(item)
    }

    /// Appends a sequence of elements.
    /// - Parameter items: The elements to append.
    public func append(_ items: [T]) {
        lock.lock()
        defer { lock.unlock() }
        array.append(contentsOf: items)
    }

    /// Returns a snapshot of all collected elements.
    public var items: [T] {
        lock.lock()
        defer { lock.unlock() }
        return array
    }

    /// Returns the current number of collected elements.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return array.count
    }

}

// MARK: - ThreadSafeObjectCollector

/// A thread-safe mutable object reference that can be read and written from multiple concurrent tasks.
///
/// Uses an ``NSLock`` internally to synchronize access.
public final class ThreadSafeObjectCollector<T>: @unchecked Sendable {

    private var object: T
    private let lock = NSLock()

    /// Creates a collector with the given initial value.
    /// - Parameter initial: The initial value.
    public init(_ initial: T) {
        object = initial
    }

    /// Atomically replaces the stored value.
    /// - Parameter item: The new value.
    public func set(_ item: T) {
        lock.lock()
        defer { lock.unlock() }
        object = item
    }

    /// Returns the current value.
    public var item: T {
        lock.lock()
        defer { lock.unlock() }
        return object
    }

}
