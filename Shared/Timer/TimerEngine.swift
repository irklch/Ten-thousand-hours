import Foundation

/// `nonisolated`: виджет, App Intents и тесты конкурентности используют его вне main actor.
nonisolated final class TimerEngine {
    enum State: Equatable {
        case idle
        case running(startDate: Date)
    }

    enum StartResult: Equatable {
        case started(SessionSnapshot)
        case alreadyRunning(SessionSnapshot)
    }

    enum StopResult: Equatable {
        case saved(SessionSnapshot)
        case discardedTooShort
        case notRunning
    }

    private(set) var state: State = .idle

    private let repository: any SessionRepository
    private let lock: FileLockCoordinator?
    private let now: () -> Date

    /// `lock` упорядочивает Play/Stop между процессами (приложение и виджет). Проверка «есть ли
    /// активная сессия» и следующая за ней запись выполняются под одной блокировкой, поэтому два одновременных Play
    /// не создадут две активные сессии, а два Stop не завершат одну сессию дважды.
    /// `nil` — только для хранилищ в памяти.
    init(
        repository: any SessionRepository,
        lock: FileLockCoordinator? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.lock = lock
        self.now = now
    }

    nonisolated deinit {}

    /// Читает состояние таймера и накопленный прогресс из хранилища под одной блокировкой.
    @discardableResult
    func restore() throws -> TrackingStatus {
        let status = try TrackingStatus.read(from: repository, lock: lock)
        state = status.activeSessionStartDate.map { .running(startDate: $0) } ?? .idle
        return status
    }

    @discardableResult
    func start() throws -> StartResult {
        try FileLockCoordinator.perform(lock, startLocked)
    }

    @discardableResult
    func stop() throws -> StopResult {
        try FileLockCoordinator.perform(lock, stopLocked)
    }

    private func startLocked() throws -> StartResult {
        if let active = try repository.activeSession() {
            state = .running(startDate: active.startDate)
            return .alreadyRunning(active)
        }
        let created = try repository.createActiveSession(startDate: SessionRules.wholeSeconds(now()))
        state = .running(startDate: created.startDate)
        return .started(created)
    }

    private func stopLocked() throws -> StopResult {
        guard let active = try repository.activeSession() else {
            state = .idle
            return .notRunning
        }
        let endDate = SessionRules.wholeSeconds(now())
        let elapsed = SessionRules.elapsedSeconds(from: active.startDate, to: endDate)

        guard elapsed >= SessionRules.minimumDurationSeconds else {
            try repository.deleteSession(id: active.id)
            state = .idle
            return .discardedTooShort
        }

        let finished = try repository.finishActiveSession(endDate: endDate, durationSeconds: elapsed)
        state = .idle
        return .saved(finished)
    }

    func currentElapsedTime() -> Int {
        switch state {
        case .idle:
            0
        case .running(let startDate):
            SessionRules.elapsedSeconds(from: startDate, to: now())
        }
    }
}
