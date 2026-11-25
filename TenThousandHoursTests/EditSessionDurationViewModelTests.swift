import XCTest
@testable import TenThousandHours

final class EditSessionDurationViewModelTests: XCTestCase {
    private struct Fixture {
        let storage: TestStorage
        let clock: TestClock
        let store: TrackingStore
        let session: SessionSnapshot
    }

    @MainActor
    private func makeFixture(
        seconds: TimeInterval = 9_240 + 41,
        failing: FailingSessionRepository? = nil,
        storage: TestStorage? = nil
    ) throws -> Fixture {
        let storage = try storage ?? TestStorage.inMemory()
        let clock = TestClock()
        let store = TrackingStore(repository: failing ?? storage.repository, now: clock.provider())
        store.restore()
        store.start()
        clock.advance(by: seconds)
        store.stop()
        clock.advance(by: 600)
        let session = try XCTUnwrap(try storage.repository.completedSessions().first)
        return Fixture(storage: storage, clock: clock, store: store, session: session)
    }

    @MainActor
    func testShowsCurrentDurationAndPrefilledFields() throws {
        let fixture = try makeFixture()
        let viewModel = EditSessionDurationViewModel(session: fixture.session, store: fixture.store)

        XCTAssertEqual(viewModel.currentDurationText, "2 ч 34 мин")
        XCTAssertEqual(viewModel.input, SessionDurationInput(hours: "2", minutes: "34"))
        XCTAssertTrue(viewModel.canSave)
        XCTAssertNil(viewModel.validationMessage)
    }

    @MainActor
    func testSavingUpdatesDurationOnlyAndDropsRemainderSeconds() throws {
        let fixture = try makeFixture()
        XCTAssertEqual(fixture.session.durationSeconds, 9_281)
        let viewModel = EditSessionDurationViewModel(session: fixture.session, store: fixture.store)

        viewModel.input.hours = "3"
        viewModel.input.minutes = "15"
        XCTAssertTrue(viewModel.save())

        let updated = try XCTUnwrap(try fixture.storage.repository.completedSessions().first)
        XCTAssertEqual(updated.durationSeconds, 11_700)
        XCTAssertEqual(updated.id, fixture.session.id)
        XCTAssertEqual(updated.startDate, fixture.session.startDate)
        XCTAssertEqual(updated.endDate, fixture.session.endDate)
        XCTAssertEqual(try fixture.storage.allSessions().count, 1)
    }

    @MainActor
    func testSavingSameMinutesStillDropsRemainderSeconds() throws {
        let fixture = try makeFixture()
        let viewModel = EditSessionDurationViewModel(session: fixture.session, store: fixture.store)

        XCTAssertTrue(viewModel.save())

        XCTAssertEqual(try fixture.storage.repository.completedSessions().first?.durationSeconds, 9_240)
    }

    @MainActor
    func testCancellingKeepsOriginalSeconds() throws {
        let fixture = try makeFixture()
        let revision = fixture.store.sessionsRevision
        let viewModel = EditSessionDurationViewModel(session: fixture.session, store: fixture.store)

        viewModel.input.hours = "7"
        viewModel.input.minutes = "0"

        XCTAssertEqual(try fixture.storage.repository.completedSessions().first?.durationSeconds, 9_281)
        XCTAssertEqual(fixture.store.totalSeconds, 9_281)
        XCTAssertEqual(fixture.store.sessionsRevision, revision)
    }

    @MainActor
    func testInvalidValuesCannotBeSaved() throws {
        let fixture = try makeFixture()
        let viewModel = EditSessionDurationViewModel(session: fixture.session, store: fixture.store)
        let cases: [(String, String)] = [("0", "0"), ("-1", "10"), ("1", "60"), ("1", "-1"), (String(Int.max), "0"), ("", "")]

        for (hours, minutes) in cases {
            viewModel.input = SessionDurationInput(hours: hours, minutes: minutes)
            XCTAssertFalse(viewModel.canSave, "\(hours):\(minutes)")
            XCTAssertNotNil(viewModel.validationMessage)
            XCTAssertFalse(viewModel.save())
        }
        XCTAssertEqual(try fixture.storage.repository.completedSessions().first?.durationSeconds, 9_281)
    }

    @MainActor
    func testSaveErrorKeepsSheetStateAndData() throws {
        let storage = try TestStorage.inMemory()
        let failing = FailingSessionRepository(wrapping: storage.repository)
        let fixture = try makeFixture(failing: failing, storage: storage)
        let viewModel = EditSessionDurationViewModel(session: fixture.session, store: fixture.store)
        viewModel.input = SessionDurationInput(hours: "5", minutes: "5")

        failing.failingOperations = [.update]
        XCTAssertFalse(viewModel.save())

        XCTAssertNotNil(viewModel.saveErrorMessage)
        XCTAssertEqual(viewModel.input, SessionDurationInput(hours: "5", minutes: "5"))
        XCTAssertFalse(viewModel.isSaving)
        XCTAssertTrue(viewModel.canSave)
        XCTAssertEqual(try storage.repository.completedSessions().first?.durationSeconds, 9_281)
        XCTAssertEqual(fixture.store.totalSeconds, 9_281)

        viewModel.dismissSaveError()
        failing.failingOperations = []
        XCTAssertTrue(viewModel.save())
        XCTAssertEqual(fixture.store.totalSeconds, 18_300)
    }

    @MainActor
    func testIncreasingAndDecreasingDurationUpdatesProgress() throws {
        let fixture = try makeFixture(seconds: 2 * 3_600)
        XCTAssertEqual(fixture.store.progress.filledDotCount, 2)

        let increase = EditSessionDurationViewModel(session: fixture.session, store: fixture.store)
        increase.input = SessionDurationInput(hours: "1245", minutes: "0")
        XCTAssertTrue(increase.save())
        XCTAssertEqual(fixture.store.progress.filledDotCount, 1_245)
        XCTAssertEqual(ProgressFormatter.percent(fixture.store.progress), "12,45%")

        let decrease = EditSessionDurationViewModel(session: fixture.session, store: fixture.store)
        decrease.input = SessionDurationInput(hours: "0", minutes: "30")
        XCTAssertTrue(decrease.save())
        XCTAssertEqual(fixture.store.progress.filledDotCount, 0)
        XCTAssertEqual(fixture.store.totalSeconds, 1_800)
        XCTAssertEqual(ProgressFormatter.percent(fixture.store.progress), "0,00%")
    }

    @MainActor
    func testEditingWhileTimerRunsKeepsActiveSession() throws {
        let fixture = try makeFixture(seconds: 3_600)
        fixture.store.start()
        let activeStart = try XCTUnwrap(try fixture.storage.repository.activeSession()?.startDate)
        fixture.clock.advance(by: 1_800)
        fixture.store.refresh()

        let viewModel = EditSessionDurationViewModel(session: fixture.session, store: fixture.store)
        viewModel.input = SessionDurationInput(hours: "2", minutes: "0")
        XCTAssertTrue(viewModel.save())

        XCTAssertTrue(fixture.store.isRunning)
        XCTAssertEqual(fixture.store.currentSessionElapsedSeconds, 1_800)
        XCTAssertEqual(fixture.store.totalSeconds, 7_200 + 1_800)
        XCTAssertEqual(try fixture.storage.repository.activeSession()?.startDate, activeStart)

        fixture.clock.advance(by: 60)
        fixture.store.refresh()
        XCTAssertEqual(fixture.store.currentSessionElapsedSeconds, 1_860)
    }

    @MainActor
    func testEditedDurationSurvivesRelaunch() throws {
        let url = try makeTemporaryStoreURL()
        let session: SessionSnapshot
        do {
            let fixture = try makeFixture(seconds: 600, storage: try TestStorage.onDisk(at: url))
            let viewModel = EditSessionDurationViewModel(session: fixture.session, store: fixture.store)
            viewModel.input = SessionDurationInput(hours: "4", minutes: "20")
            XCTAssertTrue(viewModel.save())
            session = fixture.session
        }

        let reopened = try TestStorage.onDisk(at: url)
        let store = TrackingStore(repository: reopened.repository, now: TestClock().provider())
        store.restore()
        let history = HistoryViewModel(store: store)
        history.reload()

        XCTAssertEqual(history.items.map(\.durationText), ["4 ч 20 мин"])
        XCTAssertEqual(history.items.first?.session.endDate, session.endDate)
        XCTAssertEqual(store.totalSeconds, 15_600)
    }

    @MainActor
    func testReopeningShowsUpdatedDuration() throws {
        let fixture = try makeFixture()
        let history = HistoryViewModel(store: fixture.store)
        history.reload()
        let first = history.makeEditViewModel(for: history.items[0].session)
        first.input = SessionDurationInput(hours: "1", minutes: "5")
        XCTAssertTrue(first.save())

        history.reload()
        let second = history.makeEditViewModel(for: history.items[0].session)

        XCTAssertEqual(second.currentDurationText, "1 ч 5 мин")
        XCTAssertEqual(second.input, SessionDurationInput(hours: "1", minutes: "5"))
    }

    /// Известная проблема этапа 5: запись прошла, а чтение прогресса после неё упало.
    @MainActor
    func testProgressReadFailureAfterSuccessfulSaveIsNotReportedAsSaveFailure() throws {
        let storage = try TestStorage.inMemory()
        let failing = FailingSessionRepository(wrapping: storage.repository)
        let fixture = try makeFixture(failing: failing, storage: storage)
        let viewModel = EditSessionDurationViewModel(session: fixture.session, store: fixture.store)
        viewModel.input = SessionDurationInput(hours: "5", minutes: "5")

        failing.failingOperations = [.total]
        XCTAssertTrue(viewModel.save())

        XCTAssertNil(viewModel.saveErrorMessage)
        XCTAssertEqual(fixture.store.error as? TrackingStoreError, .progressNotRefreshed)
        XCTAssertEqual(HomeViewModel(store: fixture.store).errorMessage, TrackingStoreError.progressNotRefreshed.errorDescription)
        XCTAssertEqual(try storage.repository.completedSessions().first?.durationSeconds, 18_300)

        // Закрытие сообщения перечитывает прогресс; сессия повторно не меняется.
        failing.failingOperations = [.update]
        fixture.store.dismissError()

        XCTAssertNil(fixture.store.error)
        XCTAssertEqual(fixture.store.totalSeconds, 18_300)
        XCTAssertEqual(try storage.repository.completedSessions().first?.durationSeconds, 18_300)
    }
}
