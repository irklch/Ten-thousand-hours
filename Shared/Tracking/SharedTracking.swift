import Foundation
import SwiftData
import WidgetKit

/// Access to the shared store from the widget process and from App Intents.
/// The logic is the same `TimerEngine` and repository the app uses.
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

    /// The container is cached only after a successful open: if the store is temporarily unavailable,
    /// the next call tries again.
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

/// Asks WidgetKit to rebuild the widget timeline after a data change; the system decides when to redraw.
nonisolated enum WidgetTimelineReloader {
    static func reload() {
        WidgetCenter.shared.reloadTimelines(ofKind: TrackingWidgetKind.tracking)
    }
}
