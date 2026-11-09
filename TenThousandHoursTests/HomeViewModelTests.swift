import XCTest
@testable import TenThousandHours

final class HomeViewModelTests: XCTestCase {
    @MainActor
    private func makeViewModel(
        repository: (any SessionRepository)? = nil
    ) throws -> (HomeViewModel, TestClock, TestStorage) {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let store = TrackingStore(repository: repository ?? storage.repository, now: clock.provider())
        store.restore()
        return (HomeViewModel(store: store), clock, storage)
    }

    @MainActor
    func testIdleStateShowsZeroTimerAndProgress() throws {
        let (viewModel, _, _) = try makeViewModel()

        XCTAssertFalse(viewModel.isRunning)
        XCTAssertEqual(viewModel.timerText, "00:00")
        XCTAssertEqual(viewModel.percentText, "0,00%")
        XCTAssertEqual(viewModel.hoursText, "0 / 10\u{00A0}000 ч")
        XCTAssertEqual(viewModel.filledDotCount, 0)
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testPlayStartsSessionAndShowsRunningTimer() throws {
        let (viewModel, clock, storage) = try makeViewModel()

        viewModel.togglePlayStop()
        clock.advance(by: 154)
        viewModel.store.refresh()

        XCTAssertTrue(viewModel.isRunning)
        XCTAssertNotNil(try storage.repository.activeSession())
        XCTAssertEqual(viewModel.timerText, "02:34")
    }

    @MainActor
    func testTimerShowsCurrentSessionNotAccumulatedTotal() throws {
        let (viewModel, clock, _) = try makeViewModel()
        viewModel.togglePlayStop()
        clock.advance(by: 7_200)
        viewModel.togglePlayStop()

        viewModel.togglePlayStop()
        clock.advance(by: 5)
        viewModel.store.refresh()

        XCTAssertEqual(viewModel.timerText, "00:05")
        XCTAssertEqual(viewModel.hoursText, "2 / 10\u{00A0}000 ч")
    }

    @MainActor
    func testTimerOverOneHourAndOverOneDay() throws {
        let (viewModel, clock, _) = try makeViewModel()
        viewModel.togglePlayStop()

        clock.advance(by: 3_754)
        viewModel.store.refresh()
        XCTAssertEqual(viewModel.timerText, "01:02:34")

        clock.advance(by: 86_400)
        viewModel.store.refresh()
        XCTAssertEqual(viewModel.timerText, "25:02:34")
    }

    @MainActor
    func testStopEndsSessionAndResetsTimer() throws {
        let (viewModel, clock, storage) = try makeViewModel()
        viewModel.togglePlayStop()
        clock.advance(by: 600)

        viewModel.togglePlayStop()

        XCTAssertFalse(viewModel.isRunning)
        XCTAssertEqual(viewModel.timerText, "00:00")
        XCTAssertNil(try storage.repository.activeSession())
        XCTAssertEqual(try storage.repository.completedSessions().count, 1)
    }

    @MainActor
    func testStopBeforeSixtySecondsDoesNotAddProgress() throws {
        let (viewModel, clock, storage) = try makeViewModel()
        viewModel.togglePlayStop()
        clock.advance(by: 59)

        viewModel.togglePlayStop()

        XCTAssertEqual(viewModel.store.totalSeconds, 0)
        XCTAssertEqual(viewModel.percentText, "0,00%")
        XCTAssertTrue(try storage.repository.completedSessions().isEmpty)
    }

    @MainActor
    func testStopAfterSixtySecondsUpdatesProgress() throws {
        let (viewModel, clock, _) = try makeViewModel()
        viewModel.togglePlayStop()
        clock.advance(by: 3 * 3_600 + 60)

        viewModel.togglePlayStop()

        XCTAssertEqual(viewModel.store.totalSeconds, 10_860)
        XCTAssertEqual(viewModel.percentText, "0,03%")
        XCTAssertEqual(viewModel.hoursText, "3 / 10\u{00A0}000 ч")
        XCTAssertEqual(viewModel.filledDotCount, 3)
    }

    @MainActor
    func testProgressIncludesActiveSession() throws {
        let (viewModel, clock, _) = try makeViewModel()
        viewModel.togglePlayStop()
        clock.advance(by: 1_245 * 3_600 + 1_800)
        viewModel.store.refresh()

        XCTAssertEqual(viewModel.percentText, "12,45%")
        XCTAssertEqual(viewModel.hoursText, "1\u{00A0}245 / 10\u{00A0}000 ч")
        XCTAssertEqual(viewModel.filledDotCount, 1_245)
    }

    @MainActor
    func testRelaunchRestoresActiveSession() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        HomeViewModel(store: TrackingStore(repository: storage.repository, now: clock.provider())).togglePlayStop()
        clock.advance(by: 90)

        let relaunchedStore = TrackingStore(repository: storage.repository, now: clock.provider())
        relaunchedStore.restore()
        let viewModel = HomeViewModel(store: relaunchedStore)

        XCTAssertTrue(viewModel.isRunning)
        XCTAssertEqual(viewModel.timerText, "01:30")
    }

    @MainActor
    func testStartErrorIsShownWithoutFalseRunningState() throws {
        let storage = try TestStorage.inMemory()
        let failing = FailingSessionRepository(wrapping: storage.repository)
        failing.failingOperations = [.create]
        let (viewModel, _, _) = try makeViewModel(repository: failing)

        viewModel.togglePlayStop()

        XCTAssertFalse(viewModel.isRunning)
        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertEqual(viewModel.errorMessage, "Не удалось сохранить данные. Попробуйте ещё раз.")

        viewModel.dismissError()
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testStopErrorKeepsSessionRunning() throws {
        let storage = try TestStorage.inMemory()
        let failing = FailingSessionRepository(wrapping: storage.repository)
        let (viewModel, clock, _) = try makeViewModel(repository: failing)
        viewModel.togglePlayStop()
        clock.advance(by: 120)

        failing.failingOperations = [.finish]
        viewModel.togglePlayStop()

        XCTAssertTrue(viewModel.isRunning)
        XCTAssertEqual(viewModel.timerText, "02:00")
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNotNil(try storage.repository.activeSession())
    }

    @MainActor
    func testDomainErrorUsesItsOwnDescription() throws {
        let storage = try TestStorage.inMemory()
        let store = TrackingStore(repository: DuplicateStartRepository(wrapping: storage.repository), now: TestClock().provider())
        let viewModel = HomeViewModel(store: store)

        viewModel.togglePlayStop()

        XCTAssertEqual(viewModel.errorMessage, SessionError.activeSessionAlreadyExists.errorDescription)
    }
}

@MainActor
private final class DuplicateStartRepository: SessionRepository {
    private let wrapped: any SessionRepository

    init(wrapping wrapped: any SessionRepository) {
        self.wrapped = wrapped
    }

    func activeSession() throws -> SessionSnapshot? { try wrapped.activeSession() }
    func createActiveSession(startDate: Date) throws -> SessionSnapshot { throw SessionError.activeSessionAlreadyExists }
    func finishActiveSession(endDate: Date, durationSeconds: Int) throws -> SessionSnapshot {
        try wrapped.finishActiveSession(endDate: endDate, durationSeconds: durationSeconds)
    }
    func deleteSession(id: UUID) throws { try wrapped.deleteSession(id: id) }
    func completedSessions() throws -> [SessionSnapshot] { try wrapped.completedSessions() }
    func totalCompletedDurationSeconds() throws -> Int { try wrapped.totalCompletedDurationSeconds() }
    func updateDuration(ofSessionWithID id: UUID, to durationSeconds: Int) throws -> SessionSnapshot {
        try wrapped.updateDuration(ofSessionWithID: id, to: durationSeconds)
    }
}
