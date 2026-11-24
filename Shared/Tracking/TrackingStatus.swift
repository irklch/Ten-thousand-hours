import Foundation

/// Состояние таймера и прогресса в том виде, в каком оно лежит в хранилище.
nonisolated struct TrackingStatus: Equatable, Sendable {
    let activeSessionStartDate: Date?
    let completedSessionsSeconds: Int

    var isRunning: Bool { activeSessionStartDate != nil }
    var isGoalCompleted: Bool { ProgressCalculator.isGoalCompleted(completedSessionsSeconds: completedSessionsSeconds) }

    /// Оба значения читаются под одной блокировкой, поэтому параллельный Stop не оставит виджет с остановленным
    /// таймером и прогрессом, посчитанным до сохранения сессии.
    static func read(from repository: any SessionRepository, lock: FileLockCoordinator?) throws -> TrackingStatus {
        try FileLockCoordinator.perform(lock) {
            TrackingStatus(
                activeSessionStartDate: try repository.activeSession()?.startDate,
                completedSessionsSeconds: try repository.totalCompletedDurationSeconds()
            )
        }
    }

    func progress(at date: Date) -> ProgressSnapshot {
        let activeSeconds = activeSessionStartDate.map { SessionRules.elapsedSeconds(from: $0, to: date) } ?? 0
        return ProgressCalculator.progress(
            completedSessionsSeconds: completedSessionsSeconds,
            activeSessionSeconds: activeSeconds
        )
    }
}

/// То, что нужно системным представлениям вне приложения: Live Activity (активная сессия) и напоминаниям
/// (идёт ли таймер, завершена ли цель). Читается из хранилища под одной блокировкой.
nonisolated struct TrackingSyncState: Equatable, Sendable {
    let activeSession: SessionSnapshot?
    let isGoalCompleted: Bool

    static func read(from repository: any SessionRepository, lock: FileLockCoordinator?) throws -> TrackingSyncState {
        try FileLockCoordinator.perform(lock) {
            TrackingSyncState(
                activeSession: try repository.activeSession(),
                isGoalCompleted: ProgressCalculator.isGoalCompleted(
                    completedSessionsSeconds: try repository.totalCompletedDurationSeconds()
                )
            )
        }
    }
}
