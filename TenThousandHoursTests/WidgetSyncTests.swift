import XCTest
@testable import TenThousandHours

/// The app (`TrackingStore`) and the widget (`TimerEngine` with its own container) over one store file.
final class WidgetSyncTests: XCTestCase {
    @MainActor
    func testPlayFromWidgetIsVisibleToApp() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        let app = try fixture.appStore(now: clock.provider())
        app.restore()

        try fixture.engine(now: clock.provider()).start()
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
        let revision = app.sessionsRevision

        clock.advance(by: 2 * 3_600)
        try fixture.engine(now: clock.provider()).stop()
        app.restore()

        XCTAssertFalse(app.isRunning)
        XCTAssertEqual(app.completedHours, 2)
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
        try fixture.engine(now: clock.provider()).stop()

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

        try fixture.engine(now: clock.provider()).start()
        clock.advance(by: 30)
        app.start()

        XCTAssertNil(app.error)
        XCTAssertEqual(app.currentSessionElapsedSeconds, 30)
        XCTAssertEqual(try fixture.allSessions().filter(\.isActive).count, 1)
    }

    @MainActor
    func testEditingDurationInAppIsVisibleToWidgetAndReloadsIt() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        var reloads = 0
        let app = try fixture.appStore(now: clock.provider()) { reloads += 1 }
        app.start()
        clock.advance(by: 3_600)
        app.stop()
        let session = try XCTUnwrap(try app.completedSessions().first)
        let reloadsBeforeEdit = reloads

        try app.updateDuration(ofSessionWithID: session.id, to: 5 * 3_600)

        XCTAssertEqual(reloads, reloadsBeforeEdit + 1)
        XCTAssertEqual(app.completedHours, 5)
        XCTAssertEqual(try fixture.status(), TrackingStatus(activeSessionStartDate: nil, completedSessionsSeconds: 18_000))
    }

    @MainActor
    func testAppReloadsWidgetsOnlyAfterRealChanges() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        var reloads = 0
        let app = try fixture.appStore(now: clock.provider()) { reloads += 1 }

        app.start()
        app.start()
        XCTAssertEqual(reloads, 1, "Повторный Play ничего не меняет")
        clock.advance(by: 120)
        app.stop()
        app.stop()
        XCTAssertEqual(reloads, 2, "Повторный Stop ничего не меняет")
    }

    @MainActor
    func testFailedSaveDoesNotReloadWidgets() throws {
        let storage = try TestStorage.inMemory()
        let failing = FailingSessionRepository(wrapping: storage.repository)
        failing.failingOperations = [.create]
        var reloads = 0
        let app = TrackingStore(repository: failing, onSessionsChanged: { reloads += 1 }, now: TestClock().provider())

        app.start()

        XCTAssertNotNil(app.error)
        XCTAssertFalse(app.isRunning)
        XCTAssertEqual(reloads, 0)
    }
}

/// Truly simultaneous operations: each participant runs on its own thread (`DispatchQueue.concurrentPerform`)
/// with its own `ModelContainer`, `ModelContext` and file descriptor for the lock. This is concurrency inside one
/// test process; the lock is `flock`, which works the same way for separate processes, but real separate
/// processes (app + Widget Extension) are not started here.
final class ConcurrentOperationsTests: XCTestCase {
    private let participants = 8

    private final class Results<T: Sendable>: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [Result<T, any Error>] = []

        func append(_ value: Result<T, any Error>) {
            lock.withLock { values.append(value) }
        }

        var all: [Result<T, any Error>] {
            lock.withLock { values }
        }
    }

    func testConcurrentPlaysCreateExactlyOneActiveSession() throws {
        let fixture = try SharedStoreFixture()
        let results = Results<TimerEngine.StartResult>()

        DispatchQueue.concurrentPerform(iterations: participants) { _ in
            results.append(Result { try fixture.engine().start() })
        }

        let outcomes = try results.all.map { try $0.get() }
        XCTAssertEqual(outcomes.filter { if case .started = $0 { true } else { false } }.count, 1)
        XCTAssertEqual(outcomes.count, participants)
        XCTAssertEqual(try fixture.allSessions().filter(\.isActive).count, 1)
    }

    func testConcurrentStopsFinishSessionOnce() throws {
        let fixture = try SharedStoreFixture()
        let start = Date().addingTimeInterval(-300)
        try fixture.engine(now: { start }).start()
        let results = Results<TimerEngine.StopResult>()

        DispatchQueue.concurrentPerform(iterations: participants) { _ in
            results.append(Result { try fixture.engine().stop() })
        }

        let outcomes = try results.all.map { try $0.get() }
        XCTAssertEqual(outcomes.filter { if case .saved = $0 { true } else { false } }.count, 1)
        XCTAssertEqual(outcomes.filter { $0 == .notRunning }.count, participants - 1)
        let sessions = try fixture.allSessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertFalse(try XCTUnwrap(sessions.first).isActive)
    }

    func testConcurrentPlayAndStopLeaveConsistentState() throws {
        let fixture = try SharedStoreFixture()
        let start = Date().addingTimeInterval(-300)
        try fixture.engine(now: { start }).start()
        let errors = Results<Void>()

        DispatchQueue.concurrentPerform(iterations: participants) { index in
            errors.append(Result {
                let engine = try fixture.engine()
                if index.isMultiple(of: 2) { try engine.stop() } else { try engine.start() }
            })
        }

        for result in errors.all { try result.get() }
        let sessions = try fixture.allSessions()
        XCTAssertLessThanOrEqual(sessions.filter(\.isActive).count, 1)
        XCTAssertTrue(sessions.filter { !$0.isActive }.allSatisfy { ($0.durationSeconds ?? 0) >= SessionRules.minimumDurationSeconds })
        let status = try fixture.status()
        XCTAssertEqual(status.completedSessionsSeconds, sessions.compactMap(\.durationSeconds).reduce(0, +))
    }

    func testOperationWaitsForLockHeldElsewhere() throws {
        let fixture = try SharedStoreFixture()
        let holder = try ExternalLockHolder(url: fixture.lock.lockFileURL)
        let started = Date()
        holder.release(after: 0.3)

        try fixture.engine().start()

        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), 0.25)
        XCTAssertEqual(try fixture.allSessions().count, 1)
    }

    func testOperationFailsWithoutChangesWhenLockIsNotReleased() throws {
        let fixture = try SharedStoreFixture()
        let holder = try ExternalLockHolder(url: fixture.lock.lockFileURL)
        defer { holder.release(after: 0) }
        var lock = fixture.lock
        lock.timeout = .milliseconds(100)
        let engine = TimerEngine(repository: try fixture.repository(), lock: lock)

        XCTAssertThrowsError(try engine.start()) { XCTAssertEqual($0 as? SharedStoreError, .storeBusy) }
        XCTAssertTrue(try fixture.allSessions().isEmpty)
    }
}

/// Holds the `flock` through its own file descriptor (as another participant would).
private final class ExternalLockHolder: @unchecked Sendable {
    private let descriptor: Int32

    init(url: URL) throws {
        descriptor = open(url.path, O_RDWR | O_CREAT, 0o600)
        guard descriptor >= 0, flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            throw SharedStoreError.lockUnavailable
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
