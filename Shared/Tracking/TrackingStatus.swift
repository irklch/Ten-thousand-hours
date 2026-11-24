import Foundation

/// Timer and progress state as stored in the store.
nonisolated struct TrackingStatus: Equatable, Sendable {
    let activeSessionStartDate: Date?
    let completedSessionsSeconds: Int

    var isRunning: Bool { activeSessionStartDate != nil }

    /// Both values are read under one lock, so a concurrent Stop cannot leave the widget showing a stopped
    /// timer with progress from before the session was saved.
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
