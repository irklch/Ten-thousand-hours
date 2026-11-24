import Foundation

struct HomeViewModel {
    let store: TrackingStore

    var isRunning: Bool { store.isRunning }
    var isProcessing: Bool { store.isProcessing }
    /// Вместо Play — «Начать заново»: цель достигнута и таймер не идёт (идущую сессию всё ещё можно остановить).
    var showsRestart: Bool { store.isGoalCompleted && !store.isRunning }
    var timerText: String { ElapsedTimeFormatter.clock(store.currentSessionElapsedSeconds) }
    var timerAccessibilityValue: String { ElapsedTimeFormatter.spoken(store.currentSessionElapsedSeconds) }
    var progress: ProgressDisplay { ProgressDisplay(progress: store.progress) }
    var percentText: String { progress.percentText }
    var hoursText: String { progress.hoursText }
    var filledDotCount: Int { progress.filledDotCount }

    var errorMessage: String? {
        guard let error = store.error else { return nil }
        if let sessionError = error as? SessionError {
            return sessionError.errorDescription
        }
        if let storeError = error as? SharedStoreError {
            return storeError.errorDescription
        }
        return String(localized: "Не удалось сохранить данные. Попробуйте ещё раз.")
    }

    func togglePlayStop() {
        guard !store.isProcessing else { return }
        if store.isRunning {
            store.stop()
        } else {
            store.start()
            requestNotificationsIfNeeded()
        }
    }

    func resetProgress() {
        store.resetProgress()
    }

    /// Разрешение на напоминания спрашиваем после первого Play: в этот момент понятно, зачем они нужны.
    private func requestNotificationsIfNeeded() {
        guard store.isRunning else { return }
        let store = store
        Task {
            if await DailyReminderScheduler.requestAuthorizationIfNeeded() {
                store.syncSystemState()
            }
        }
    }

    func dismissError() {
        store.dismissError()
    }

    func keepTimerUpdated() async {
        await store.keepRefreshing()
    }
}
