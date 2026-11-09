import XCTest
@testable import TenThousandHours

final class TimerEngineTests: XCTestCase {
    @MainActor
    func testFirstStartCreatesActiveSession() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let engine = TimerEngine(repository: storage.repository, now: clock.provider())

        let result = try engine.start()

        let active = try XCTUnwrap(try storage.repository.activeSession())
        XCTAssertEqual(result, .started(active))
        XCTAssertEqual(active.startDate, clock.now)
        XCTAssertEqual(engine.state, .running(startDate: clock.now))
    }

    @MainActor
    func testSecondStartDoesNotCreateAnotherSession() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let engine = TimerEngine(repository: storage.repository, now: clock.provider())

        try engine.start()
        clock.advance(by: 30)
        let second = try engine.start()

        let sessions = try storage.allSessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(second, .alreadyRunning(try XCTUnwrap(sessions.first?.snapshot)))
        XCTAssertEqual(engine.currentElapsedTime(), 30)
    }

    @MainActor
    func testStartFromSecondEngineReusesPersistedActiveSession() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let first = TimerEngine(repository: storage.repository, now: clock.provider())
        let second = TimerEngine(repository: storage.repository, now: clock.provider())

        try first.start()
        let result = try second.start()

        guard case .alreadyRunning = result else {
            return XCTFail("Ожидалась уже запущенная сессия, получено \(result)")
        }
        XCTAssertEqual(try storage.allSessions().count, 1)
    }

    @MainActor
    func testConcurrentStartsCreateSingleActiveSession() async throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let engine = TimerEngine(repository: storage.repository, now: clock.provider())

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask { @MainActor in
                    try engine.start()
                }
            }
            try await group.waitForAll()
        }

        XCTAssertEqual(try storage.allSessions().count, 1)
    }

    @MainActor
    func testStopFinishesActiveSession() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let engine = TimerEngine(repository: storage.repository, now: clock.provider())

        try engine.start()
        let startDate = clock.now
        clock.advance(by: 120)
        let result = try engine.stop()

        let completed = try storage.repository.completedSessions()
        XCTAssertEqual(completed.count, 1)
        XCTAssertEqual(result, .saved(completed[0]))
        XCTAssertEqual(completed[0].startDate, startDate)
        XCTAssertEqual(completed[0].endDate, clock.now)
        XCTAssertEqual(completed[0].durationSeconds, 120)
        XCTAssertNil(try storage.repository.activeSession())
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.currentElapsedTime(), 0)
    }

    @MainActor
    func testRepeatedStopIsSafe() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let engine = TimerEngine(repository: storage.repository, now: clock.provider())

        try engine.start()
        clock.advance(by: 90)
        try engine.stop()
        clock.advance(by: 90)
        let second = try engine.stop()

        XCTAssertEqual(second, .notRunning)
        XCTAssertEqual(try storage.repository.completedSessions().count, 1)
        XCTAssertEqual(try storage.repository.totalCompletedDurationSeconds(), 90)
    }

    @MainActor
    func testStopWhenIdleIsSafe() throws {
        let storage = try TestStorage.inMemory()
        let engine = TimerEngine(repository: storage.repository, now: TestClock().provider())

        XCTAssertEqual(try engine.stop(), .notRunning)
        XCTAssertTrue(try storage.allSessions().isEmpty)
    }

    @MainActor
    func testStopAfter59SecondsDiscardsSession() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let engine = TimerEngine(repository: storage.repository, now: clock.provider())

        try engine.start()
        clock.advance(by: 59.9)
        let result = try engine.stop()

        XCTAssertEqual(result, .discardedTooShort)
        XCTAssertTrue(try storage.allSessions().isEmpty)
        XCTAssertEqual(engine.state, .idle)
    }

    @MainActor
    func testStopAfter60SecondsSavesSession() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let engine = TimerEngine(repository: storage.repository, now: clock.provider())

        try engine.start()
        clock.advance(by: 60)
        try engine.stop()

        XCTAssertEqual(try storage.repository.completedSessions().map(\.durationSeconds), [60])
    }

    @MainActor
    func testStopAfter61SecondsSavesExactDuration() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let engine = TimerEngine(repository: storage.repository, now: clock.provider())

        try engine.start()
        clock.advance(by: 61)
        try engine.stop()

        XCTAssertEqual(try storage.repository.completedSessions().map(\.durationSeconds), [61])
    }

    @MainActor
    func testElapsedTimeIsCountedInWholeSecondsFromAbsoluteTimestamps() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock(Date(timeIntervalSinceReferenceDate: 800_000_000.7))
        let engine = TimerEngine(repository: storage.repository, now: clock.provider())

        try engine.start()
        XCTAssertEqual(engine.state, .running(startDate: Date(timeIntervalSinceReferenceDate: 800_000_000)))

        clock.advance(by: 100.2)
        XCTAssertEqual(engine.currentElapsedTime(), 100)

        clock.advance(by: 0.2)
        try engine.stop()
        XCTAssertEqual(try storage.repository.completedSessions().first?.durationSeconds, 101)
    }

    @MainActor
    func testRestoreAfterRelaunchResumesActiveSession() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let startDate = clock.now
        try TimerEngine(repository: storage.repository, now: clock.provider()).start()

        clock.advance(by: 300)
        let relaunched = TimerEngine(repository: storage.repository, now: clock.provider())
        XCTAssertEqual(relaunched.state, .idle)
        try relaunched.restore()

        XCTAssertEqual(relaunched.state, .running(startDate: startDate))
        XCTAssertEqual(relaunched.currentElapsedTime(), 300)
    }

    @MainActor
    func testClosedAppKeepsCountingUntilStop() throws {
        let url = try makeTemporaryStoreURL()
        let clock = TestClock()

        do {
            let storage = try TestStorage.onDisk(at: url)
            try TimerEngine(repository: storage.repository, now: clock.provider()).start()
        }

        clock.advance(by: 2 * 3_600 + 15)

        let storage = try TestStorage.onDisk(at: url)
        let engine = TimerEngine(repository: storage.repository, now: clock.provider())
        try engine.restore()
        XCTAssertEqual(engine.currentElapsedTime(), 7_215)

        try engine.stop()
        XCTAssertEqual(try storage.repository.totalCompletedDurationSeconds(), 7_215)
    }

    @MainActor
    func testSessionLongerThan24HoursIsSavedExactly() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let engine = TimerEngine(repository: storage.repository, now: clock.provider())
        let duration = 3 * 86_400 + 4 * 3_600 + 5 * 60 + 6

        try engine.start()
        clock.advance(by: TimeInterval(duration))
        XCTAssertEqual(engine.currentElapsedTime(), duration)
        try engine.stop()

        XCTAssertEqual(try storage.repository.completedSessions().first?.durationSeconds, duration)
    }

    @MainActor
    func testClockMovedBackwardsNeverProducesNegativeTime() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let engine = TimerEngine(repository: storage.repository, now: clock.provider())

        try engine.start()
        clock.advance(by: -3_600)
        XCTAssertEqual(engine.currentElapsedTime(), 0)

        XCTAssertEqual(try engine.stop(), .discardedTooShort)
        XCTAssertTrue(try storage.allSessions().isEmpty)
    }

    @MainActor
    func testFailedStartLeavesEngineIdle() throws {
        let storage = try TestStorage.inMemory()
        let repository = FailingSessionRepository(wrapping: storage.repository)
        repository.failingOperations = [.create]
        let engine = TimerEngine(repository: repository, now: TestClock().provider())

        XCTAssertThrowsError(try engine.start()) { error in
            XCTAssertEqual(error as? InjectedSaveError, InjectedSaveError())
        }
        XCTAssertEqual(engine.state, .idle)
        XCTAssertTrue(try storage.allSessions().isEmpty)
    }

    @MainActor
    func testFailedStopKeepsEngineRunningAndSessionActive() throws {
        let storage = try TestStorage.inMemory()
        let repository = FailingSessionRepository(wrapping: storage.repository)
        let clock = TestClock()
        let engine = TimerEngine(repository: repository, now: clock.provider())
        try engine.start()
        let startDate = clock.now
        clock.advance(by: 600)

        repository.failingOperations = [.finish]
        XCTAssertThrowsError(try engine.stop())

        XCTAssertEqual(engine.state, .running(startDate: startDate))
        XCTAssertEqual(try storage.repository.activeSession()?.startDate, startDate)
        XCTAssertTrue(try storage.repository.completedSessions().isEmpty)

        repository.failingOperations = []
        clock.advance(by: 60)
        XCTAssertEqual(try engine.stop(), .saved(try XCTUnwrap(try storage.repository.completedSessions().first)))
        XCTAssertEqual(try storage.repository.totalCompletedDurationSeconds(), 660)
    }

    @MainActor
    func testFailedDiscardKeepsEngineRunning() throws {
        let storage = try TestStorage.inMemory()
        let repository = FailingSessionRepository(wrapping: storage.repository)
        let clock = TestClock()
        let engine = TimerEngine(repository: repository, now: clock.provider())
        try engine.start()
        clock.advance(by: 10)

        repository.failingOperations = [.delete]
        XCTAssertThrowsError(try engine.stop())

        XCTAssertNotEqual(engine.state, .idle)
        XCTAssertNotNil(try storage.repository.activeSession())
    }
}
