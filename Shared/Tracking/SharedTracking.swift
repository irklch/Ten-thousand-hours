import Foundation
import SwiftData
import WidgetKit

/// Доступ к общему хранилищу из процесса виджета и из App Intents.
/// Логика — те же `TimerEngine` и репозиторий, что использует приложение.
enum SharedTracking {
    private static var cachedContainer: ModelContainer?

    static func engine() throws -> TimerEngine {
        let (repository, lock) = try storage()
        return TimerEngine(repository: repository, lock: lock)
    }

    static func status() throws -> TrackingStatus {
        let (repository, lock) = try storage()
        return try TrackingStatus.read(from: repository, lock: lock)
    }

    /// После сохранённого Play/Stop: виджеты получают запрос на перезагрузку, а Live Activity приводится
    /// в соответствие с тем, что сейчас лежит в SwiftData. Если хранилище не читается, ошибка выходит из `perform`.
    static func didChange() async {
        WidgetTimelineReloader.reload()
        do {
            let (repository, lock) = try storage()
            let active = try FileLockCoordinator.perform(lock) { try repository.activeSession() }
            await LiveActivityController.sync(activeSession: active)
        } catch {
            LiveActivityController.logSyncFailure(error)
        }
    }

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
