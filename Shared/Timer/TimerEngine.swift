import Foundation

final class TimerEngine {
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
    private let coordinator: any SessionOperationCoordinator
    private let now: () -> Date

    /// `coordinator` serializes Play/Stop across processes (the app and the widget). The check
    /// "is there an active session" and the write that follows it run under a single lock, so two
    /// simultaneous Plays cannot create two active sessions, and two Stops cannot finish one session twice.
    init(
        repository: any SessionRepository,
        coordinator: any SessionOperationCoordinator = InProcessOperationCoordinator(),
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.coordinator = coordinator
        self.now = now
    }

    nonisolated deinit {}

    func restore() throws {
        state = Self.state(for: try repository.activeSession())
    }

    @discardableResult
    func start() throws -> StartResult {
        try coordinator.perform(startLocked)
    }

    @discardableResult
    func stop() throws -> StopResult {
        try coordinator.perform(stopLocked)
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

    private static func state(for activeSession: SessionSnapshot?) -> State {
        activeSession.map { .running(startDate: $0.startDate) } ?? .idle
    }
}
