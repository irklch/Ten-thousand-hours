import Foundation
import SwiftData

/// Moves sessions from the app's local store (before stage 6) to the shared store in the App Group.
///
/// Only the app runs it (the widget has no access to the app sandbox), under the same cross-process lock as Play/Stop.
///
/// 1. If the completion marker exists, the migration has already run and nothing is done.
/// 2. If there is no legacy store, there is nothing to move: the marker is written right away.
/// 3. Sessions are read from the legacy store and copied into the shared store with the same `id`,
///    `startDate`, `endDate` and `durationSeconds`. Sessions whose `id` is already in the shared store
///    are skipped, so a repeated or interrupted migration creates no duplicates.
/// 4. Everything is written in a single `save()` (one SQLite transaction). Then the shared store is
///    re-read and compared with the source.
/// 5. The marker is written only after a successful check.
///
/// The legacy store is never deleted. If any step fails, it stays untouched and the migration is
/// repeated on the next launch.
struct StoreMigrator {
    enum Outcome: Equatable {
        case alreadyMigrated
        case noLegacyStore
        case migrated(copied: Int, alreadyPresent: Int)
    }

    let legacyStoreURL: URL
    let location: SharedStoreLocation
    let coordinator: any SessionOperationCoordinator
    var fileManager: FileManager = .default
    var openContainer: (URL) throws -> ModelContainer = { try ModelContainerFactory.makeContainer(storeURL: $0) }
    /// Test hook: simulates an interruption after the data is written but before the marker is.
    var beforeMarkingComplete: () throws -> Void = {}

    @discardableResult
    func migrateIfNeeded() throws -> Outcome {
        try coordinator.perform(migrateLocked)
    }

    private func migrateLocked() throws -> Outcome {
        if location.isMigrationComplete(fileManager: fileManager) {
            return .alreadyMigrated
        }
        guard fileManager.fileExists(atPath: legacyStoreURL.path) else {
            try markComplete()
            return .noLegacyStore
        }

        let legacySessions = try Self.fetchAll(in: openContainer(legacyStoreURL))
        let target = try openContainer(location.storeURL)
        let context = ModelContext(target)
        context.autosaveEnabled = false

        let existing = try context.fetch(FetchDescriptor<Session>())
        let existingIDs = Set(existing.map(\.id))
        let existingActive = existing.first { $0.endDate == nil }

        var copied = 0
        for snapshot in legacySessions where !existingIDs.contains(snapshot.id) {
            if snapshot.isActive, existingActive != nil {
                // Before the marker exists, nobody writes to the shared store except this migration,
                // so a foreign active session means the data is inconsistent. Changing nothing is safer.
                throw SharedStoreError.activeSessionConflict
            }
            let session = Session(id: snapshot.id, startDate: snapshot.startDate)
            session.endDate = snapshot.endDate
            session.durationSeconds = snapshot.durationSeconds
            context.insert(session)
            copied += 1
        }

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
        }

        try verify(legacySessions, in: target)
        try beforeMarkingComplete()
        try markComplete()
        return .migrated(copied: copied, alreadyPresent: legacySessions.count - copied)
    }

    private func verify(_ legacySessions: [SessionSnapshot], in container: ModelContainer) throws {
        let migrated = Dictionary(
            try Self.fetchAll(in: container).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for snapshot in legacySessions where migrated[snapshot.id] != snapshot {
            throw SharedStoreError.migrationVerificationFailed
        }
    }

    private func markComplete() throws {
        try Data("1".utf8).write(to: location.migrationMarkerURL, options: .atomic)
    }

    private static func fetchAll(in container: ModelContainer) throws -> [SessionSnapshot] {
        try ModelContext(container).fetch(FetchDescriptor<Session>()).map(\.snapshot)
    }
}
