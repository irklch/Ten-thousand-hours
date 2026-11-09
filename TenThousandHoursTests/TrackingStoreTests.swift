import XCTest
@testable import TenThousandHours

final class TrackingStoreTests: XCTestCase {
    @MainActor
    func testStartAndStopUpdateObservableState() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let store = TrackingStore(repository: storage.repository, now: clock.provider())
        store.restore()

        store.start()
        XCTAssertTrue(store.isRunning)
        XCTAssertFalse(store.isProcessing)

        clock.advance(by: 3_600)
        store.refresh()
        XCTAssertEqual(store.currentSessionElapsedSeconds, 3_600)
        XCTAssertEqual(store.totalSeconds, 3_600)
        XCTAssertEqual(store.completedHours, 1)

        store.stop()
        XCTAssertFalse(store.isRunning)
        XCTAssertEqual(store.currentSessionElapsedSeconds, 0)
        XCTAssertEqual(store.totalSeconds, 3_600)
        XCTAssertNil(store.error)
    }

    @MainActor
    func testActiveSessionIsNotCountedTwice() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let store = TrackingStore(repository: storage.repository, now: clock.provider())

        store.start()
        clock.advance(by: 7_200)
        store.stop()
        store.start()
        clock.advance(by: 1_800)
        store.refresh()

        XCTAssertEqual(store.totalSeconds, 9_000)
        XCTAssertEqual(store.completedHours, 2)

        store.stop()
        XCTAssertEqual(store.totalSeconds, 9_000)
        XCTAssertEqual(try storage.repository.totalCompletedDurationSeconds(), 9_000)
    }

    @MainActor
    func testRestoreIncludesPersistedHistoryAndActiveSession() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let first = TrackingStore(repository: storage.repository, now: clock.provider())
        first.start()
        clock.advance(by: 5_000)
        first.stop()
        first.start()
        clock.advance(by: 100)

        let relaunched = TrackingStore(repository: storage.repository, now: clock.provider())
        relaunched.restore()

        XCTAssertTrue(relaunched.isRunning)
        XCTAssertEqual(relaunched.currentSessionElapsedSeconds, 100)
        XCTAssertEqual(relaunched.totalSeconds, 5_100)
    }

    @MainActor
    func testGoalReachedDuringActiveSessionKeepsTimerRunning() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let store = TrackingStore(repository: storage.repository, now: clock.provider())

        store.start()
        clock.advance(by: TimeInterval(ProgressGoal.targetSeconds + 60))
        store.refresh()

        XCTAssertTrue(store.goalReached)
        XCTAssertTrue(store.isRunning)
        XCTAssertEqual(store.progressPercent, 100)
    }

    @MainActor
    func testSaveErrorDoesNotReportSuccessfulStart() throws {
        let storage = try TestStorage.inMemory()
        let repository = FailingSessionRepository(wrapping: storage.repository)
        repository.failingOperations = [.create]
        let store = TrackingStore(repository: repository, now: TestClock().provider())

        store.start()

        XCTAssertFalse(store.isRunning)
        XCTAssertFalse(store.isProcessing)
        XCTAssertNotNil(store.error)
        XCTAssertNil(try storage.repository.activeSession())
    }

    @MainActor
    func testSaveErrorDoesNotReportSuccessfulStop() throws {
        let storage = try TestStorage.inMemory()
        let repository = FailingSessionRepository(wrapping: storage.repository)
        let clock = TestClock()
        let store = TrackingStore(repository: repository, now: clock.provider())
        store.start()
        clock.advance(by: 120)

        repository.failingOperations = [.finish]
        store.stop()

        XCTAssertTrue(store.isRunning)
        XCTAssertNotNil(store.error)
        XCTAssertEqual(store.currentSessionElapsedSeconds, 120)
        XCTAssertNotNil(try storage.repository.activeSession())

        store.dismissError()
        XCTAssertNil(store.error)
    }

    @MainActor
    func testSeveralRefreshClientsShareOneTicker() async throws {
        let storage = try TestStorage.inMemory()
        let store = TrackingStore(repository: storage.repository, now: TestClock().provider())
        XCTAssertFalse(store.isTicking)

        let home = Task { await store.keepRefreshing() }
        let fullscreen = Task { await store.keepRefreshing() }
        for _ in 0..<5 { await Task.yield() }
        XCTAssertTrue(store.isTicking)

        home.cancel()
        await home.value
        XCTAssertTrue(store.isTicking)

        fullscreen.cancel()
        await fullscreen.value
        XCTAssertFalse(store.isTicking)
    }

    @MainActor
    func testNewFullHourFillsNextDotWhileRunning() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let store = TrackingStore(repository: storage.repository, now: clock.provider())
        store.start()

        clock.advance(by: 3_599)
        store.refresh()
        XCTAssertEqual(store.progress.filledDotCount, 0)

        clock.advance(by: 1)
        store.refresh()
        XCTAssertEqual(store.progress.filledDotCount, 1)
    }
}
