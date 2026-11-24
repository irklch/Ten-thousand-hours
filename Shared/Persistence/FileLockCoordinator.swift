import Foundation

/// Mutual exclusion between processes (the app and the Widget Extension) for operations that change sessions.
///
/// `@MainActor`, actors and in-memory locks only work inside one process, so the lock is a `flock` on a
/// file next to the store in the App Group. The operation holds it for milliseconds and has no suspension
/// points. If the process crashes, the system releases the lock itself. Waiting is bounded by `timeout`,
/// after which the operation fails with `storeBusy` without changes.
nonisolated struct FileLockCoordinator: Sendable {
    let lockFileURL: URL
    var timeout: Duration = .seconds(3)

    func perform<T>(_ operation: () throws -> T) throws -> T {
        let descriptor = try acquire()
        defer {
            flock(descriptor, LOCK_UN)
            close(descriptor)
        }
        return try operation()
    }

    private func acquire() throws -> Int32 {
        let descriptor = open(lockFileURL.path, O_RDWR | O_CREAT | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else {
            throw SharedStoreError.lockUnavailable
        }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            let code = errno
            guard code == EWOULDBLOCK || code == EINTR else {
                close(descriptor)
                throw SharedStoreError.lockUnavailable
            }
            guard clock.now < deadline else {
                close(descriptor)
                throw SharedStoreError.storeBusy
            }
            usleep(5_000)
        }
        return descriptor
    }
}

nonisolated extension FileLockCoordinator {
    /// Runs the operation under the lock if there is one (stores in memory for tests and Preview have no lock).
    static func perform<T>(_ lock: FileLockCoordinator?, _ operation: () throws -> T) throws -> T {
        guard let lock else { return try operation() }
        return try lock.perform(operation)
    }
}
