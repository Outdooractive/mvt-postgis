import Foundation

extension Task where Failure == Error {

    @discardableResult
    static func after(
        seconds: TimeInterval,
        priority: TaskPriority? = nil,
        operation: @escaping @Sendable () async throws -> Success
    ) -> Task {
        Task(priority: priority) {
            let delay = UInt64(seconds * 1_000_000_000)
            try await Task<Never, Never>.sleep(nanoseconds: delay)

            return try await operation()
        }
    }

    @discardableResult
    static func background(
        _ operation: @escaping @Sendable () async throws -> Success
    ) -> Task {
        Task(priority: .background, operation: operation)
    }

    @discardableResult
    static func userInitiated(
        _ operation: @escaping @Sendable () async throws -> Success
    ) -> Task {
        Task(priority: .userInitiated, operation: operation)
    }

}
