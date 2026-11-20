import Foundation
import OSLog
import SwiftData

/// Picks the app's store at launch.
///
/// Normally this is the shared store in the App Group: first the legacy local store is migrated into it
/// (`StoreMigrator`). If the App Group is unavailable, or the migration or opening the shared store fails,
/// the app keeps working with the legacy local store. No data is lost, widgets show "Откройте приложение",
/// and the migration is retried on the next launch. The error is shown to the user.
///
/// While running on the local store, the migration marker is removed. The widget then stops working with
/// the shared store (no divergence), and on the next successful launch the sessions recorded locally are
/// added to the shared store (merging by `id`, without duplicates).
struct PersistenceBootstrap {
    struct Result {
        let container: ModelContainer
        let coordinator: any SessionOperationCoordinator
        let isShared: Bool
        let sharedStoreError: (any Error)?
    }

    var legacyStoreURL: URL = LegacyStoreLocation.storeURL
    var resolveLocation: () throws -> SharedStoreLocation = { try SharedStoreLocation.appGroup() }
    var openContainer: (URL) throws -> ModelContainer = { try ModelContainerFactory.makeContainer(storeURL: $0) }

    func prepare() throws -> Result {
        var resolvedLocation: SharedStoreLocation?
        do {
            let location = try resolveLocation()
            resolvedLocation = location
            let coordinator = FileLockCoordinator(lockFileURL: location.lockFileURL)
            let migrator = StoreMigrator(
                legacyStoreURL: legacyStoreURL,
                location: location,
                coordinator: coordinator,
                openContainer: openContainer
            )
            try migrator.migrateIfNeeded()
            let container = try openContainer(location.storeURL)
            return Result(container: container, coordinator: coordinator, isShared: true, sharedStoreError: nil)
        } catch {
            if let resolvedLocation {
                invalidateMigration(at: resolvedLocation)
            }
            let container = try openContainer(legacyStoreURL)
            return Result(
                container: container,
                coordinator: InProcessOperationCoordinator(),
                isShared: false,
                sharedStoreError: error
            )
        }
    }

    private func invalidateMigration(at location: SharedStoreLocation) {
        let marker = location.migrationMarkerURL
        guard FileManager.default.fileExists(atPath: marker.path) else { return }
        do {
            try FileManager.default.removeItem(at: marker)
        } catch {
            Logger.persistence.error("Не удалось снять маркер миграции: \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension Logger {
    static let persistence = Logger(subsystem: "com.irklch.TenThousandHours", category: "Persistence")
}
