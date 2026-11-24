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
    private let preferences: SharedPreferences?
    private let now: () -> Date

    /// `lock` упорядочивает Play/Stop между процессами (приложение и виджет). Проверка «есть ли
    /// активная сессия» и следующая за ней запись выполняются под одной блокировкой, поэтому два одновременных Play
    /// не создадут две активные сессии, а два Stop не завершат одну сессию дважды.
    /// `nil` — только для хранилищ в памяти.
    /// `preferences` получает время последнего Play/Stop, чтобы не напоминать о цели в день, когда таймер запускали.
    init(
        repository: any SessionRepository,
        lock: FileLockCoordinator? = nil,
        preferences: SharedPreferences? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.lock = lock
        self.preferences = preferences
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

    /// «Начать заново»: удаляет все сессии одним сохранением. Разрешено только после достижения цели и без
    /// активной сессии — оба условия перепроверяются под блокировкой, а не берутся из состояния интерфейса.
    func resetCompletedGoal() throws {
        try FileLockCoordinator.perform(lock) {
            guard try repository.activeSession() == nil else {
                throw SessionError.activeSessionAlreadyExists
            }
            guard ProgressCalculator.isGoalCompleted(
                completedSessionsSeconds: try repository.totalCompletedDurationSeconds()
            ) else {
                throw SessionError.goalNotCompleted
            }
            try repository.deleteAllSessions()
            state = .idle
        }
    }

    private func startLocked() throws -> StartResult {
        if let active = try repository.activeSession() {
            state = .running(startDate: active.startDate)
            return .alreadyRunning(active)
        }
        // После 10 000 часов новый цикл начинается только через сброс, откуда бы ни пришёл Play.
        guard !ProgressCalculator.isGoalCompleted(
            completedSessionsSeconds: try repository.totalCompletedDurationSeconds()
        ) else {
            throw SessionError.goalCompleted
        }
        let created = try repository.createActiveSession(startDate: SessionRules.wholeSeconds(now()))
        state = .running(startDate: created.startDate)
        preferences?.recordTracking(at: created.startDate)
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
            preferences?.recordTracking(at: endDate)
            return .discardedTooShort
        }

        let finished = try repository.finishActiveSession(endDate: endDate, durationSeconds: elapsed)
        state = .idle
        // Сессия могла идти несколько дней: день остановки тоже считается днём занятий.
        preferences?.recordTracking(at: endDate)
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
