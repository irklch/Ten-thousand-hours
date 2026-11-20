import Foundation

struct HomeViewModel {
    let store: TrackingStore

    var isRunning: Bool { store.isRunning }
    var isProcessing: Bool { store.isProcessing }
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
        return String(localized: "Не удалось сохранить данные. Попробуйте ещё раз.")
    }

    func togglePlayStop() {
        guard !store.isProcessing else { return }
        if store.isRunning {
            store.stop()
        } else {
            store.start()
        }
    }

    func dismissError() {
        store.dismissError()
    }

    func keepTimerUpdated() async {
        await store.keepRefreshing()
    }
}
