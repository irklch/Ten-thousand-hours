import XCTest
@testable import TenThousandHours

/// The app and the widget as two "processes" over one store file.
final class WidgetSyncTests: XCTestCase {
    @MainActor
    func testPlayFromWidgetIsVisibleToApp() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        let app = try fixture.appStore(now: clock.provider())
        app.restore()
        let widget = try fixture.process(now: clock.provider())

        try widget.start()
        clock.advance(by: 90)
        app.restore()

        XCTAssertTrue(app.isRunning)
        XCTAssertEqual(app.currentSessionElapsedSeconds, 90)
        XCTAssertEqual(try fixture.allSessions().count, 1)
    }

    @MainActor
    func testStopFromWidgetUpdatesAppStateHistoryAndProgress() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        let app = try fixture.appStore(now: clock.provider())
        app.start()
        XCTAssertTrue(app.isRunning)
        let revision = app.sessionsRevision

        clock.advance(by: 2 * 3_600)
        try fixture.process(now: clock.provider()).stop()
        app.restore()

        XCTAssertFalse(app.isRunning)
        XCTAssertEqual(app.completedHours, 2)
        XCTAssertEqual(app.totalSeconds, 7_200)
        XCTAssertGreaterThan(app.sessionsRevision, revision)
        XCTAssertEqual(try app.completedSessions().map(\.durationSeconds), [7_200])
    }

    @MainActor
    func testAppStopAfterWidgetStopDoesNotFinishSessionTwice() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        let app = try fixture.appStore(now: clock.provider())
        app.start()
        clock.advance(by: 600)
        try fixture.process(now: clock.provider()).stop()

        clock.advance(by: 600)
        app.stop()

        XCTAssertNil(app.error)
        XCTAssertFalse(app.isRunning)
        XCTAssertEqual(try fixture.allSessions().map(\.durationSeconds), [600])
    }

    @MainActor
    func testAppPlayAfterWidgetPlayDoesNotCreateSecondSession() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        let app = try fixture.appStore(now: clock.provider())
        app.restore()
        XCTAssertFalse(app.isRunning)

        try fixture.process(now: clock.provider()).start()
        clock.advance(by: 30)
        app.start()

        XCTAssertNil(app.error)
        XCTAssertTrue(app.isRunning)
        XCTAssertEqual(app.currentSessionElapsedSeconds, 30)
        XCTAssertEqual(try fixture.allSessions().filter(\.isActive).count, 1)
    }

    @MainActor
    func testEditingDurationInAppIsVisibleToWidget() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        var changes = 0
        let app = try fixture.appStore(now: clock.provider()) { changes += 1 }
        app.start()
        clock.advance(by: 3_600)
        app.stop()
        let session = try XCTUnwrap(try app.completedSessions().first)
        let changesBeforeEdit = changes

        try app.updateDuration(ofSessionWithID: session.id, to: 5 * 3_600)

        XCTAssertEqual(changes, changesBeforeEdit + 1, "После редактирования виджет должен перезагрузиться")
        XCTAssertEqual(
            SharedTracking.widgetState(location: fixture.location),
            .ready(TrackingStatus(activeSessionStartDate: nil, completedSessionsSeconds: 18_000))
        )
    }

    @MainActor
    func testAppReloadsWidgetsOnlyAfterRealChanges() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        var changes = 0
        let app = try fixture.appStore(now: clock.provider()) { changes += 1 }

        app.start()
        XCTAssertEqual(changes, 1)
        app.start()
        XCTAssertEqual(changes, 1, "Повторный Play ничего не меняет")
        clock.advance(by: 120)
        app.stop()
        XCTAssertEqual(changes, 2)
        app.stop()
        XCTAssertEqual(changes, 2, "Повторный Stop ничего не меняет")
    }

    @MainActor
    func testFailedSaveDoesNotReloadWidgets() throws {
        let clock = TestClock()
        let storage = try TestStorage.inMemory()
        let failing = FailingSessionRepository(wrapping: storage.repository)
        failing.failingOperations = [.create]
        var changes = 0
        let app = TrackingStore(repository: failing, onSessionsChanged: { changes += 1 }, now: clock.provider())

        app.start()

        XCTAssertNotNil(app.error)
        XCTAssertFalse(app.isRunning)
        XCTAssertEqual(changes, 0)
    }
}

/// Coordination of simultaneous operations from different processes.
final class SessionOperationCoordinatorTests: XCTestCase {
    @MainActor
    func testSimultaneousPlaysFromSeveralProcessesCreateOneActiveSession() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        // Three "processes" (the app and two widgets) have each read "the timer is stopped" and press Play.
        let processes = try (0..<3).map { _ in try fixture.process(now: clock.provider()) }
        XCTAssertTrue(try processes.allSatisfy { try !$0.status().isRunning })

        let results = try processes.map { try $0.start() }

        XCTAssertEqual(results.filter { if case .started = $0 { true } else { false } }.count, 1)
        XCTAssertEqual(try fixture.allSessions().filter(\.isActive).count, 1)
    }

    @MainActor
    func testSimultaneousStopsFinishSessionOnce() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        let app = try fixture.process(now: clock.provider())
        let widget = try fixture.process(now: clock.provider())
        try app.start()
        clock.advance(by: 300)

        let first = try widget.stop()
        clock.advance(by: 5)
        let second = try app.stop()

        guard case .saved = first else { return XCTFail("Ожидалось сохранение, получено \(first)") }
        XCTAssertEqual(second, .notRunning)
        XCTAssertEqual(try fixture.allSessions().map(\.durationSeconds), [300])
    }

    @MainActor
    func testOperationWaitsWhileAnotherProcessHoldsLock() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        let holder = try ExternalLockHolder(url: fixture.location.lockFileURL)
        let started = Date()
        holder.release(after: 0.3)

        try fixture.process(now: clock.provider()).start()

        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), 0.25)
        XCTAssertEqual(try fixture.allSessions().count, 1)
    }

    @MainActor
    func testOperationFailsWithoutChangesWhenLockIsNotReleased() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        let holder = try ExternalLockHolder(url: fixture.location.lockFileURL)
        defer { holder.release(after: 0) }
        let widget = TrackingCommands(
            repository: SwiftDataSessionRepository(
                container: try ModelContainerFactory.makeContainer(storeURL: fixture.location.storeURL)
            ),
            coordinator: FileLockCoordinator(lockFileURL: fixture.location.lockFileURL, timeout: .milliseconds(100)),
            now: clock.provider()
        )

        XCTAssertThrowsError(try widget.start()) { error in
            XCTAssertEqual(error as? SharedStoreError, .storeBusy)
        }
        XCTAssertTrue(try fixture.allSessions().isEmpty)
    }

    @MainActor
    func testNestedOperationDoesNotDeadlock() throws {
        let fixture = try SharedStoreFixture()
        let coordinator = FileLockCoordinator(lockFileURL: fixture.location.lockFileURL, timeout: .milliseconds(100))

        let value = try coordinator.perform { try coordinator.perform { 42 } }

        XCTAssertEqual(value, 42)
    }
}

/// Holds the `flock` through its own file descriptor, as another process would.
private final class ExternalLockHolder: @unchecked Sendable {
    private let descriptor: Int32

    init(url: URL) throws {
        descriptor = open(url.path, O_RDWR | O_CREAT, 0o600)
        guard descriptor >= 0, flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            throw SharedStoreError.lockUnavailable(errno: errno)
        }
    }

    func release(after delay: TimeInterval) {
        let descriptor = descriptor
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            flock(descriptor, LOCK_UN)
            close(descriptor)
        }
    }
}
