import Foundation
import SwiftData
import WidgetKit

/// Доступ к общему хранилищу из процесса виджета и из App Intents.
/// Логика — те же `TimerEngine` и репозиторий, что использует приложение.
enum SharedTracking {
    private static var cachedContainer: ModelContainer?

    static func engine() throws -> TimerEngine {
        let (repository, lock) = try storage()
        return TimerEngine(repository: repository, lock: lock, preferences: .shared)
    }

    static func status() throws -> TrackingStatus {
        let (repository, lock) = try storage()
        return try TrackingStatus.read(from: repository, lock: lock)
    }

    /// После сохранённого Play/Stop: виджеты получают запрос на перезагрузку, а Live Activity и напоминания
    /// приводятся в соответствие с тем, что сейчас лежит в SwiftData. Если хранилище не читается, ошибка выходит из `perform`.
    static func didChange() async {
        WidgetTimelineReloader.reload()
        do {
            let (repository, lock) = try storage()
            await syncSystemState(try TrackingSyncState.read(from: repository, lock: lock)).value
        } catch {
            LiveActivityController.logSyncFailure(error)
        }
    }

    /// Общий для приложения и intents шаг: Live Activity и напоминания следуют за состоянием из хранилища.
    /// Вызовы выполняются строго по очереди (`SerialTaskQueue`): при быстрых Play/Stop более старое
    /// состояние не может примениться после более нового — ни запросить activity для уже остановленной
    /// сессии, ни вернуть отменённые напоминания. Постановка в очередь синхронная — сразу после чтения состояния.
    @discardableResult
    static func syncSystemState(_ state: TrackingSyncState) -> Task<Void, Never> {
        systemStateQueue.enqueue {
            await LiveActivityController.sync(activeSession: state.activeSession)
            await DailyReminderScheduler.reschedule(
                isRunning: state.activeSession != nil,
                isGoalCompleted: state.isGoalCompleted
            )
        }
    }

    private static let systemStateQueue = SerialTaskQueue()

    /// Контейнер кэшируется только после успешного открытия: если хранилище временно недоступно,
    /// следующий вызов попробует снова.
    private static func storage() throws -> (SwiftDataSessionRepository, FileLockCoordinator) {
        let storeURL = try ModelContainerFactory.sharedStoreURL()
        let container = try cachedContainer ?? ModelContainerFactory.makeContainer(storeURL: storeURL)
        cachedContainer = container
        return (
            SwiftDataSessionRepository(container: container),
            FileLockCoordinator(lockFileURL: ModelContainerFactory.lockFileURL(forStoreAt: storeURL))
        )
    }
}

nonisolated enum TrackingWidgetKind {
    static let tracking = "TenThousandHoursTrackingWidget"
}

/// Просит WidgetKit пересобрать таймлайн виджета после изменения данных; когда перерисовать, решает система.
nonisolated enum WidgetTimelineReloader {
    static func reload() {
        WidgetCenter.shared.reloadTimelines(ofKind: TrackingWidgetKind.tracking)
    }
}

/// Выполняет асинхронные операции по одной в порядке вызова `enqueue`: каждая следующая ждёт завершения предыдущей.
/// Постановка в очередь синхронная, поэтому порядок операций совпадает с порядком чтений состояния из хранилища.
final class SerialTaskQueue {
    private var last: Task<Void, Never>?

    @discardableResult
    func enqueue(_ operation: @escaping () async -> Void) -> Task<Void, Never> {
        let previous = last
        let current = Task {
            await previous?.value
            await operation()
        }
        last = current
        return current
    }
}
