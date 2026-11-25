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
    /// Завершённые сессии дают не меньше 10 000 часов: новый Play недоступен до «Начать заново».
    private(set) var isGoalCompleted = false
    /// Цель достигнута, а поздравление в этом цикле ещё не показано (в том числе если цель достигнута из виджета).
    private(set) var isCelebrationPending = false

    var totalSeconds: Int { progress.totalSeconds }
    var completedHours: Int { progress.completedHours }
    var progressPercent: Double { progress.progressPercent }
    var goalReached: Bool { progress.goalReached }

    @ObservationIgnored private let engine: TimerEngine
    @ObservationIgnored private let repository: any SessionRepository
    @ObservationIgnored private let lock: FileLockCoordinator?
    @ObservationIgnored private let onSessionsChanged: () -> Void
    @ObservationIgnored private let onStateRead: (TrackingSyncState) -> Void
    @ObservationIgnored private let onTimerStarted: () -> Void
    @ObservationIgnored private let preferences: SharedPreferences
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var completedSessionsSeconds = 0
    @ObservationIgnored private var refreshClientCount = 0
    @ObservationIgnored private var tickerTask: Task<Void, Never>?

    /// - Parameters:
    ///   - lock: та же межпроцессная блокировка, что использует виджет; `nil` только для хранилищ в памяти.
    ///   - onSessionsChanged: вызывается после успешного сохранения Play, Stop и правки длительности
    ///     (в приложении перезагружает таймлайн виджета).
    ///   - onStateRead: вызывается с состоянием из хранилища после успешного восстановления, Play, Stop,
    ///     правки длительности и сброса (в приложении приводит в соответствие Live Activity и напоминания).
    ///   - onTimerStarted: вызывается после Play в приложении, создавшего сессию (в приложении — запрос
    ///     разрешения на напоминания).
    ///   - preferences: время последнего Play/Stop и флаг показанного поздравления (в приложении — App Group).
    init(
        repository: any SessionRepository,
        lock: FileLockCoordinator? = nil,
        preferences: SharedPreferences = .ephemeral(),
        onSessionsChanged: @escaping () -> Void = {},
        onStateRead: @escaping (TrackingSyncState) -> Void = { _ in },
        onTimerStarted: @escaping () -> Void = {},
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.lock = lock
        self.preferences = preferences
        self.onSessionsChanged = onSessionsChanged
        self.onStateRead = onStateRead
        self.onTimerStarted = onTimerStarted
        self.now = now
        self.engine = TimerEngine(repository: repository, lock: lock, preferences: preferences, now: now)
    }

    nonisolated deinit {}

    func restore() {
        perform {
            try reloadStatus()
            sessionsRevision += 1
            try reportState()
        }
    }

    /// Перед действием заново читает состояние из хранилища: сессию могли уже запустить или
    /// остановить из виджета, и одному состоянию в памяти доверять нельзя.
    func start() {
        perform {
            let result = try engine.start()
            if case .started = result {
                onSessionsChanged()
                onTimerStarted()
            }
            try reloadStatus()
            try reportState()
        }
    }

    func stop() {
        perform {
            let result = try engine.stop()
            try reloadStatus()
            sessionsRevision += 1
            if result != .notRunning {
                onSessionsChanged()
            }
            try reportState()
        }
    }

    /// «Начать заново» после 10 000 часов. Условия перепроверяет `TimerEngine` под межпроцессной блокировкой;
    /// при ошибке сохранения сессии не удаляются, прогресс не обнуляется, а `error` получает ошибку.
    func resetProgress() {
        perform {
            try engine.resetCompletedGoal()
            preferences.isGoalCelebrationShown = false
            try reloadStatus()
            sessionsRevision += 1
            onSessionsChanged()
            try reportState()
        }
    }

    func dismissCelebration() {
        guard isCelebrationPending else { return }
        preferences.isGoalCelebrationShown = true
        isCelebrationPending = false
    }

    private func reportState() throws {
        onStateRead(try TrackingSyncState.read(from: repository, lock: lock))
    }

    private func reloadStatus() throws {
        completedSessionsSeconds = try engine.restore().completedSessionsSeconds
        isGoalCompleted = ProgressCalculator.isGoalCompleted(completedSessionsSeconds: completedSessionsSeconds)
        // Правка истории вернула цель в незавершённое состояние: при повторном достижении поздравим снова.
        if !isGoalCompleted, preferences.isGoalCelebrationShown {
            preferences.isGoalCelebrationShown = false
        }
        isCelebrationPending = isGoalCompleted && !preferences.isGoalCelebrationShown
    }

    func completedSessions() throws -> [SessionSnapshot] {
        try repository.completedSessions()
    }

    @discardableResult
    func updateDuration(ofSessionWithID id: UUID, to durationSeconds: Int) throws -> SessionSnapshot {
        let updated = try FileLockCoordinator.perform(lock) {
            try repository.updateDuration(ofSessionWithID: id, to: durationSeconds)
        }
        // Длительность уже сохранена. Если прогресс после этого не прочитался, это не ошибка сохранения:
        // показываем отдельное сообщение, а прогресс перечитывается при закрытии сообщения и при каждом
        // возврате в приложение (`restore`) — без повторного изменения сессии.
        onSessionsChanged()
        do {
            try reloadStatus()
            try reportState()
        } catch {
            self.error = TrackingStoreError.progressNotRefreshed
        }
        sessionsRevision += 1
        refresh()
        return updated
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
        let needsProgressReload = error as? TrackingStoreError == .progressNotRefreshed
        error = nil
        if needsProgressReload {
            restore()
        }
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

enum TrackingStoreError: LocalizedError, Equatable {
    /// Изменение сохранено, но накопленный прогресс не удалось перечитать.
    case progressNotRefreshed

    var errorDescription: String? {
        String(localized: "Изменения сохранены, но прогресс не обновился. Он обновится при следующем открытии приложения.")
    }
}
