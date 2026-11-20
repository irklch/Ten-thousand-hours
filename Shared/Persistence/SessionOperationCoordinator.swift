import Foundation

/// Serializes the operations that change sessions (Play, Stop, duration edit, migration).
///
/// The app and the Widget Extension are separate processes. Neither `@MainActor` nor an actor nor an
/// in-memory lock excludes one process from the other, so the shared store uses `FileLockCoordinator`.
/// Its `flock` lock lives in the App Group container and is visible to both processes.
protocol SessionOperationCoordinator: AnyObject {
    func perform<T>(_ operation: () throws -> T) throws -> T
}

/// For a store that only one process uses: in-memory storage, tests, and the local fallback.
final class InProcessOperationCoordinator: SessionOperationCoordinator {
    nonisolated deinit {}

    func perform<T>(_ operation: () throws -> T) throws -> T {
        try operation()
    }
}

/// Exclusive lock on a file (`flock`) shared by every process that has access to the App Group.
///
/// - Every operation holds the lock for a few milliseconds and contains no suspension points, so the
///   process cannot be suspended by the system while it holds the lock.
/// - If a process crashes, the system releases its `flock` automatically, so the lock cannot "hang".
/// - Waiting is bounded by `timeout`; after that the operation fails with an error and the state is
///   left unchanged.
/// - Re-entering from the same instance does not take the lock again (otherwise the process would
///   block itself).
final class FileLockCoordinator: SessionOperationCoordinator {
    private let lockFileURL: URL
    private let timeout: Duration
    private var depth = 0

    init(lockFileURL: URL, timeout: Duration = .seconds(3)) {
        self.lockFileURL = lockFileURL
        self.timeout = timeout
    }

    nonisolated deinit {}

    func perform<T>(_ operation: () throws -> T) throws -> T {
        if depth > 0 {
            return try operation()
        }
        let descriptor = try acquire()
        depth += 1
        defer {
            depth -= 1
            flock(descriptor, LOCK_UN)
            close(descriptor)
        }
        return try operation()
    }

    private func acquire() throws -> Int32 {
        let descriptor = open(lockFileURL.path, O_RDWR | O_CREAT | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else {
            throw SharedStoreError.lockUnavailable(errno: errno)
        }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            let code = errno
            guard code == EWOULDBLOCK || code == EINTR else {
                close(descriptor)
                throw SharedStoreError.lockUnavailable(errno: code)
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
