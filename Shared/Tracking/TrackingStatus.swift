import Foundation

/// Состояние таймера и прогресса в том виде, в каком оно лежит в хранилище.
nonisolated struct TrackingStatus: Equatable, Sendable {
    let activeSessionStartDate: Date?
    let completedSessionsSeconds: Int

    var isRunning: Bool { activeSessionStartDate != nil }

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
