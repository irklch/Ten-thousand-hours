import Foundation
import Observation

@Observable
final class TrackingStore {
    private(set) var isRunning = false
    private(set) var currentSessionElapsedSeconds = 0
    private(set) var progress = ProgressCalculator.progress(completedSessionsSeconds: 0, activeSessionSeconds: 0)
    private(set) var isProcessing = false
    private(set) var error: (any Error)?

    var totalSeconds: Int { progress.totalSeconds }
    var completedHours: Int { progress.completedHours }
    var progressPercent: Double { progress.progressPercent }
    var goalReached: Bool { progress.goalReached }

    @ObservationIgnored private let engine: TimerEngine
    @ObservationIgnored private let repository: any SessionRepository
    @ObservationIgnored private var completedSessionsSeconds = 0

    init(repository: any SessionRepository, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.engine = TimerEngine(repository: repository, now: now)
    }

    func restore() {
        perform {
            try engine.restore()
            completedSessionsSeconds = try repository.totalCompletedDurationSeconds()
        }
    }

    func start() {
        perform {
            try engine.start()
        }
    }

    func stop() {
        perform {
            try engine.stop()
            completedSessionsSeconds = try repository.totalCompletedDurationSeconds()
        }
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

    func keepRefreshing(interval: Duration = .seconds(1)) async {
        while !Task.isCancelled {
            refresh()
            do {
                try await Task.sleep(for: interval)
            } catch is CancellationError {
                return
            } catch {
                self.error = error
                return
            }
        }
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
