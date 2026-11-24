import Foundation
import Observation

@Observable
final class TrackingStore {
    private(set) var isRunning = false
    private(set) var currentSessionElapsedSeconds = 0
    private(set) var progress = ProgressCalculator.progress(completedSessionsSeconds: 0, activeSessionSeconds: 0)
    private(set) var isProcessing = false
    private(set) var error: (any Error)?
    private(set) var sessionsRevision = 0

    var totalSeconds: Int { progress.totalSeconds }
    var completedHours: Int { progress.completedHours }
    var progressPercent: Double { progress.progressPercent }
    var goalReached: Bool { progress.goalReached }

    @ObservationIgnored private let engine: TimerEngine
    @ObservationIgnored private let repository: any SessionRepository
    @ObservationIgnored private let lock: FileLockCoordinator?
    @ObservationIgnored private let onSessionsChanged: () -> Void
    @ObservationIgnored private let onActiveSessionRead: (SessionSnapshot?) -> Void
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var completedSessionsSeconds = 0
    @ObservationIgnored private var refreshClientCount = 0
    @ObservationIgnored private var tickerTask: Task<Void, Never>?

    /// - Parameters:
    ///   - lock: the same cross-process lock the widget uses; `nil` only for stores in memory.
    ///   - onSessionsChanged: called after Play, Stop and a duration edit are saved successfully
    ///     (in the app this reloads the widget timeline).
    ///   - onActiveSessionRead: called with the active session from the store after a successful restore,
    ///     Play and Stop (in the app this reconciles the Live Activity).
    init(
        repository: any SessionRepository,
        lock: FileLockCoordinator? = nil,
        onSessionsChanged: @escaping () -> Void = {},
        onActiveSessionRead: @escaping (SessionSnapshot?) -> Void = { _ in },
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.lock = lock
        self.onSessionsChanged = onSessionsChanged
        self.onActiveSessionRead = onActiveSessionRead
        self.now = now
        self.engine = TimerEngine(repository: repository, lock: lock, now: now)
    }

    nonisolated deinit {}

    func restore() {
        perform {
            completedSessionsSeconds = try engine.restore().completedSessionsSeconds
            sessionsRevision += 1
            try reportActiveSession()
        }
    }

    /// Re-reads the state from the store before acting: the session may already have been started or
    /// stopped from the widget, and the memory state alone is not trusted.
    func start() {
        perform {
            let result = try engine.start()
            if case .started = result {
                onSessionsChanged()
            }
            completedSessionsSeconds = try engine.restore().completedSessionsSeconds
            try reportActiveSession()
        }
    }

    func stop() {
        perform {
            let result = try engine.stop()
            completedSessionsSeconds = try engine.restore().completedSessionsSeconds
            sessionsRevision += 1
            if result != .notRunning {
                onSessionsChanged()
            }
            try reportActiveSession()
        }
    }

    private func reportActiveSession() throws {
        onActiveSessionRead(try FileLockCoordinator.perform(lock) { try repository.activeSession() })
    }

    func completedSessions() throws -> [SessionSnapshot] {
        try repository.completedSessions()
    }

    @discardableResult
    func updateDuration(ofSessionWithID id: UUID, to durationSeconds: Int) throws -> SessionSnapshot {
        let updated = try FileLockCoordinator.perform(lock) {
            try repository.updateDuration(ofSessionWithID: id, to: durationSeconds)
        }
        reloadProgress()
        onSessionsChanged()
        return updated
    }

    func reloadProgress() {
        do {
            completedSessionsSeconds = try engine.restore().completedSessionsSeconds
        } catch {
            self.error = error
        }
        sessionsRevision += 1
        refresh()
    }

    func refresh() {
        isRunning = engine.state != .idle
        currentSessionElapsedSeconds = engine.currentElapsedTime()
        progress = ProgressCalculator.progress(
            completedSessionsSeconds: completedSessionsSeconds,
            activeSessionSeconds: currentSessionElapsedSeconds
        )
    }

    func dismissError() {
        error = nil
    }

    func keepRefreshing() async {
        refreshClientCount += 1
        if refreshClientCount == 1 {
            startTicker()
        }
        await waitUntilCancelled()
        refreshClientCount -= 1
        if refreshClientCount == 0 {
            tickerTask?.cancel()
            tickerTask = nil
        }
    }

    var isTicking: Bool {
        tickerTask != nil
    }

    private func startTicker() {
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.refresh()
                do {
                    try await Task.sleep(for: self.delayUntilNextSecond())
                } catch is CancellationError {
                    return
                } catch {
                    self.error = error
                    return
                }
            }
        }
    }

    private func waitUntilCancelled() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(3_600))
            } catch is CancellationError {
                return
            } catch {
                self.error = error
                return
            }
        }
    }

    private func delayUntilNextSecond() -> Duration {
        let fraction = now().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
        let delay = fraction >= 0 ? 1 - fraction : -fraction
        return .milliseconds(Int(delay * 1_000) + 10)
    }

    private func perform(_ operation: () throws -> Void) {
        guard !isProcessing else { return }
        isProcessing = true
        defer {
            isProcessing = false
            refresh()
        }
        do {
            try operation()
            error = nil
        } catch {
            self.error = error
        }
    }
}
