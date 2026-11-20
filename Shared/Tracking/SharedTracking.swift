import Foundation
import SwiftData
import WidgetKit

/// Access to the shared store from the widget process and from App Intents.
enum SharedTracking {
    private static var cachedContainer: (url: URL, container: ModelContainer)?

    /// Commands over the shared store. Throws `migrationPending` until the app has migrated the legacy
    /// data: otherwise the widget would show an empty progress and start a session in an empty store.
    static func commands(location: SharedStoreLocation? = nil) throws -> TrackingCommands {
        let location = try location ?? SharedStoreLocation.appGroup()
        guard location.isMigrationComplete() else {
            throw SharedStoreError.migrationPending
        }
        return TrackingCommands(
            repository: SwiftDataSessionRepository(container: try container(at: location.storeURL)),
            coordinator: FileLockCoordinator(lockFileURL: location.lockFileURL)
        )
    }

    private static func container(at url: URL) throws -> ModelContainer {
        if let cachedContainer, cachedContainer.url == url {
            return cachedContainer.container
        }
        let container = try ModelContainerFactory.makeContainer(storeURL: url)
        cachedContainer = (url, container)
        return container
    }
}

nonisolated enum TrackingWidgetKind {
    static let tracking = "TenThousandHoursTrackingWidget"
}

/// Asks WidgetKit to rebuild the widget timeline after a data change.
/// The system decides when to actually redraw; reloads are not called more often than data changes.
nonisolated enum WidgetTimelineReloader {
    static func reload() {
        WidgetCenter.shared.reloadTimelines(ofKind: TrackingWidgetKind.tracking)
    }
}
