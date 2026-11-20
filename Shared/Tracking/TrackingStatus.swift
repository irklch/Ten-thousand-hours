import Foundation

/// Timer and progress state as stored in the shared store, without any in-memory state.
nonisolated struct TrackingStatus: Equatable, Sendable {
    let activeSessionStartDate: Date?
    let completedSessionsSeconds: Int

    var isRunning: Bool { activeSessionStartDate != nil }

    func progress(at date: Date) -> ProgressSnapshot {
        let activeSeconds = activeSessionStartDate.map { SessionRules.elapsedSeconds(from: $0, to: date) } ?? 0
        return ProgressCalculator.progress(
            completedSessionsSeconds: completedSessionsSeconds,
            activeSessionSeconds: activeSeconds
        )
    }
}

/// Play/Stop and state reads on top of the shared store. Used by the App Intents and the widget timeline.
/// The timer logic itself is the shared `TimerEngine`; there is no separate implementation.
struct TrackingCommands {
    let repository: any SessionRepository
    let coordinator: any SessionOperationCoordinator
    var now: () -> Date = Date.init

    @discardableResult
    func start() throws -> TimerEngine.StartResult {
        try makeEngine().start()
    }

    @discardableResult
    func stop() throws -> TimerEngine.StopResult {
        try makeEngine().stop()
    }

    func status() throws -> TrackingStatus {
        TrackingStatus(
            activeSessionStartDate: try repository.activeSession()?.startDate,
            completedSessionsSeconds: try repository.totalCompletedDurationSeconds()
        )
    }

    private func makeEngine() -> TimerEngine {
        TimerEngine(repository: repository, coordinator: coordinator, now: now)
    }
}
