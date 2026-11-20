import SwiftData
import XCTest
@testable import TenThousandHours

final class StoreMigratorTests: XCTestCase {
    private struct InjectedInterruption: Error {}
    private struct TargetUnavailable: Error {}

    @MainActor
    private func makeMigrator(
        legacy: URL,
        location: SharedStoreLocation,
        openContainer: @escaping (URL) throws -> ModelContainer = { try ModelContainerFactory.makeContainer(storeURL: $0) },
        beforeMarkingComplete: @escaping () throws -> Void = {}
    ) -> StoreMigrator {
        StoreMigrator(
            legacyStoreURL: legacy,
            location: location,
            coordinator: FileLockCoordinator(lockFileURL: location.lockFileURL),
            openContainer: openContainer,
            beforeMarkingComplete: beforeMarkingComplete
        )
    }

    /// The legacy store with completed sessions and, optionally, an active one.
    @MainActor
    private func makeLegacyStore(completed: [Int] = [], activeStart: Date? = nil) throws -> (URL, [SessionSnapshot]) {
        let url = try makeTemporaryDirectory().appendingPathComponent("default.store")
        let context = ModelContext(try ModelContainerFactory.makeContainer(storeURL: url))
        var start = Date(timeIntervalSinceReferenceDate: 790_000_000)
        for duration in completed {
            let session = Session(startDate: start)
            session.endDate = start.addingTimeInterval(TimeInterval(duration))
            session.durationSeconds = duration
            context.insert(session)
            start = start.addingTimeInterval(86_400)
        }
        if let activeStart {
            context.insert(Session(startDate: activeStart))
        }
        try context.save()
        let snapshots = try context.fetch(FetchDescriptor<Session>()).map(\.snapshot)
        return (url, snapshots)
    }

    @MainActor
    func testMissingLegacyStoreMarksMigrationComplete() throws {
        let location = try SharedStoreFixture(migrated: false).location
        let legacy = try makeTemporaryDirectory().appendingPathComponent("default.store")

        XCTAssertEqual(try makeMigrator(legacy: legacy, location: location).migrateIfNeeded(), .noLegacyStore)
        XCTAssertTrue(location.isMigrationComplete())
    }

    @MainActor
    func testEmptyLegacyStore() throws {
        let fixture = try SharedStoreFixture(migrated: false)
        let (legacy, _) = try makeLegacyStore()

        XCTAssertEqual(
            try makeMigrator(legacy: legacy, location: fixture.location).migrateIfNeeded(),
            .migrated(copied: 0, alreadyPresent: 0)
        )
        XCTAssertTrue(fixture.location.isMigrationComplete())
        XCTAssertTrue(try fixture.allSessions().isEmpty)
    }

    @MainActor
    func testCompletedSessionsKeepIdentifiersDatesAndDurations() throws {
        let fixture = try SharedStoreFixture(migrated: false)
        let (legacy, original) = try makeLegacyStore(completed: [3_600, 5_400, 61])

        XCTAssertEqual(
            try makeMigrator(legacy: legacy, location: fixture.location).migrateIfNeeded(),
            .migrated(copied: 3, alreadyPresent: 0)
        )

        XCTAssertEqual(Set(try fixture.allSessions().map(\.id)), Set(original.map(\.id)))
        XCTAssertEqual(
            try fixture.allSessions().sorted { $0.startDate < $1.startDate },
            original.sorted { $0.startDate < $1.startDate }
        )
    }

    @MainActor
    func testActiveSessionKeepsRunningAfterMigration() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture(migrated: false)
        let activeStart = clock.now.addingTimeInterval(-600)
        let (legacy, _) = try makeLegacyStore(completed: [7_200], activeStart: activeStart)

        try makeMigrator(legacy: legacy, location: fixture.location).migrateIfNeeded()

        let status = try fixture.process(now: clock.provider()).status()
        XCTAssertEqual(status, TrackingStatus(activeSessionStartDate: activeStart, completedSessionsSeconds: 7_200))
    }

    @MainActor
    func testRepeatedMigrationDoesNothing() throws {
        let fixture = try SharedStoreFixture(migrated: false)
        let (legacy, _) = try makeLegacyStore(completed: [3_600, 7_200])
        let migrator = makeMigrator(legacy: legacy, location: fixture.location)

        try migrator.migrateIfNeeded()
        XCTAssertEqual(try migrator.migrateIfNeeded(), .alreadyMigrated)

        XCTAssertEqual(try fixture.allSessions().count, 2)
    }

    @MainActor
    func testInterruptedMigrationResumesWithoutDuplicates() throws {
        let fixture = try SharedStoreFixture(migrated: false)
        let (legacy, original) = try makeLegacyStore(completed: [3_600, 7_200], activeStart: Date(timeIntervalSinceReferenceDate: 800_000_000))

        let interrupted = makeMigrator(
            legacy: legacy,
            location: fixture.location,
            beforeMarkingComplete: { throw InjectedInterruption() }
        )
        XCTAssertThrowsError(try interrupted.migrateIfNeeded())
        XCTAssertFalse(fixture.location.isMigrationComplete(), "Маркер не должен появиться до конца миграции")
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.path))

        let resumed = try makeMigrator(legacy: legacy, location: fixture.location).migrateIfNeeded()

        XCTAssertEqual(resumed, .migrated(copied: 0, alreadyPresent: 3))
        XCTAssertTrue(fixture.location.isMigrationComplete())
        XCTAssertEqual(try fixture.allSessions().count, 3)
        XCTAssertEqual(Set(try fixture.allSessions().map(\.id)), Set(original.map(\.id)))
    }

    @MainActor
    func testTargetOpenFailureKeepsLegacyDataAndRetriesLater() throws {
        let fixture = try SharedStoreFixture(migrated: false)
        let (legacy, original) = try makeLegacyStore(completed: [3_600])
        let target = fixture.location.storeURL
        let failing = makeMigrator(legacy: legacy, location: fixture.location, openContainer: { url in
            if url == target { throw TargetUnavailable() }
            return try ModelContainerFactory.makeContainer(storeURL: url)
        })

        XCTAssertThrowsError(try failing.migrateIfNeeded()) { XCTAssertTrue($0 is TargetUnavailable) }
        XCTAssertFalse(fixture.location.isMigrationComplete())
        let legacyContext = ModelContext(try ModelContainerFactory.makeContainer(storeURL: legacy))
        XCTAssertEqual(try legacyContext.fetch(FetchDescriptor<Session>()).map(\.snapshot), original)

        XCTAssertEqual(
            try makeMigrator(legacy: legacy, location: fixture.location).migrateIfNeeded(),
            .migrated(copied: 1, alreadyPresent: 0)
        )
    }

    @MainActor
    func testLegacyStoreIsNotDeleted() throws {
        let fixture = try SharedStoreFixture(migrated: false)
        let (legacy, original) = try makeLegacyStore(completed: [3_600])

        try makeMigrator(legacy: legacy, location: fixture.location).migrateIfNeeded()

        let legacyContext = ModelContext(try ModelContainerFactory.makeContainer(storeURL: legacy))
        XCTAssertEqual(try legacyContext.fetch(FetchDescriptor<Session>()).map(\.snapshot), original)
    }

    @MainActor
    func testForeignActiveSessionInTargetStopsMigrationWithoutChanges() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture(migrated: false)
        let (legacy, _) = try makeLegacyStore(activeStart: clock.now)
        let foreign = try ModelContainerFactory.makeContainer(storeURL: fixture.location.storeURL)
        let context = ModelContext(foreign)
        context.insert(Session(startDate: clock.now.addingTimeInterval(-60)))
        try context.save()

        XCTAssertThrowsError(try makeMigrator(legacy: legacy, location: fixture.location).migrateIfNeeded()) {
            XCTAssertEqual($0 as? SharedStoreError, .activeSessionConflict)
        }
        XCTAssertFalse(fixture.location.isMigrationComplete())
        XCTAssertEqual(try fixture.allSessions().filter(\.isActive).count, 1)
    }
}

final class PersistenceBootstrapTests: XCTestCase {
    private struct SharedOpenFailure: Error {}

    @MainActor
    func testUsesSharedStoreAfterMigration() throws {
        let location = try SharedStoreFixture(migrated: false).location
        let legacy = try makeTemporaryDirectory().appendingPathComponent("default.store")
        let bootstrap = PersistenceBootstrap(legacyStoreURL: legacy, resolveLocation: { location })

        let result = try bootstrap.prepare()

        XCTAssertTrue(result.isShared)
        XCTAssertNil(result.sharedStoreError)
        XCTAssertTrue(result.coordinator is FileLockCoordinator)
        XCTAssertEqual(result.container.configurations.first?.url, location.storeURL)
    }

    @MainActor
    func testFallsBackToLegacyStoreWhenAppGroupIsUnavailable() throws {
        let legacy = try makeTemporaryDirectory().appendingPathComponent("default.store")
        let bootstrap = PersistenceBootstrap(
            legacyStoreURL: legacy,
            resolveLocation: { throw SharedStoreError.appGroupUnavailable }
        )

        let result = try bootstrap.prepare()

        XCTAssertFalse(result.isShared)
        XCTAssertEqual(result.sharedStoreError as? SharedStoreError, .appGroupUnavailable)
        XCTAssertEqual(result.container.configurations.first?.url, legacy)
    }

    @MainActor
    func testFallsBackToLegacyStoreWhenSharedStoreCannotBeOpened() throws {
        let location = try SharedStoreFixture(migrated: false).location
        let legacy = try makeTemporaryDirectory().appendingPathComponent("default.store")
        let bootstrap = PersistenceBootstrap(
            legacyStoreURL: legacy,
            resolveLocation: { location },
            openContainer: { url in
                if url == location.storeURL { throw SharedOpenFailure() }
                return try ModelContainerFactory.makeContainer(storeURL: url)
            }
        )

        let result = try bootstrap.prepare()

        XCTAssertFalse(result.isShared)
        XCTAssertTrue(result.sharedStoreError is SharedOpenFailure)
        XCTAssertEqual(result.container.configurations.first?.url, legacy)
    }
}

extension PersistenceBootstrapTests {
    @MainActor
    func testFallbackStopsWidgetAndMergesLocalSessionsOnNextLaunch() throws {
        let fixture = try SharedStoreFixture(migrated: false)
        let location = fixture.location
        let legacy = try makeTemporaryDirectory().appendingPathComponent("default.store")
        var sharedAvailable = true
        let bootstrap = PersistenceBootstrap(
            legacyStoreURL: legacy,
            resolveLocation: { location },
            openContainer: { url in
                if url == location.storeURL, !sharedAvailable { throw SharedOpenFailure() }
                return try ModelContainerFactory.makeContainer(storeURL: url)
            }
        )
        XCTAssertTrue(try bootstrap.prepare().isShared)

        sharedAvailable = false
        let fallback = try bootstrap.prepare()
        XCTAssertFalse(fallback.isShared)
        XCTAssertFalse(location.isMigrationComplete(), "Виджет не должен работать с общим хранилищем, пока приложение на локальном")
        let clock = TestClock()
        let local = TimerEngine(repository: SwiftDataSessionRepository(container: fallback.container), now: clock.provider())
        try local.start()
        clock.advance(by: 600)
        try local.stop()

        sharedAvailable = true
        XCTAssertTrue(try bootstrap.prepare().isShared)
        XCTAssertEqual(try fixture.allSessions().map(\.durationSeconds), [600])
    }
}
