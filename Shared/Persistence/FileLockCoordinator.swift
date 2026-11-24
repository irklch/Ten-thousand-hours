import Foundation

/// Взаимное исключение между процессами (приложение и Widget Extension) для операций, меняющих сессии.
///
/// `@MainActor`, акторы и блокировки в памяти работают только внутри одного процесса, поэтому блокировка — это `flock`
/// на файле рядом с хранилищем в App Group. Операция держит её миллисекунды и не имеет точек
/// приостановки. Если процесс падает, система сама снимает блокировку. Ожидание ограничено `timeout`,
/// после чего операция завершается с `storeBusy` без изменений.
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
    /// Выполняет операцию под блокировкой, если она есть (у хранилищ в памяти для тестов и Preview блокировки нет).
    static func perform<T>(_ lock: FileLockCoordinator?, _ operation: () throws -> T) throws -> T {
        guard let lock else { return try operation() }
        return try lock.perform(operation)
    }
}
