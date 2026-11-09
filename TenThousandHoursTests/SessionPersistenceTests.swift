import XCTest
@testable import TenThousandHours

final class SessionPersistenceTests: XCTestCase {
    @MainActor
    func testSessionsSurviveContainerRecreationOnDisk() throws {
        let url = try makeTemporaryStoreURL()
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

        do {
            let storage = try TestStorage.onDisk(at: url)
            _ = try storage.repository.createActiveSession(startDate: start)
            _ = try storage.repository.finishActiveSession(endDate: start.addingTimeInterval(5_400), durationSeconds: 5_400)
            _ = try storage.repository.createActiveSession(startDate: start.addingTimeInterval(10_000))
        }

        let reopened = try TestStorage.onDisk(at: url)
        let completed = try reopened.repository.completedSessions()
        XCTAssertEqual(completed.count, 1)
        XCTAssertEqual(completed[0].startDate, start)
        XCTAssertEqual(completed[0].endDate, start.addingTimeInterval(5_400))
        XCTAssertEqual(completed[0].durationSeconds, 5_400)
        XCTAssertEqual(try reopened.repository.activeSession()?.startDate, start.addingTimeInterval(10_000))
    }

    @MainActor
    func testOnlyOneActiveSessionCanExist() throws {
        let storage = try TestStorage.inMemory()
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        _ = try storage.repository.createActiveSession(startDate: start)

        XCTAssertThrowsError(try storage.repository.createActiveSession(startDate: start.addingTimeInterval(1))) { error in
            XCTAssertEqual(error as? SessionError, .activeSessionAlreadyExists)
        }
        XCTAssertEqual(try storage.allSessions().count, 1)
    }

    @MainActor
    func testCompletedSessionsAreSortedNewestFirstAndSummed() throws {
        let storage = try TestStorage.inMemory()
        let base = Date(timeIntervalSinceReferenceDate: 800_000_000)
        for (offset, duration) in [(0, 3_600), (10_000, 1_800), (20_000, 61)] {
            let start = base.addingTimeInterval(TimeInterval(offset))
            _ = try storage.repository.createActiveSession(startDate: start)
            _ = try storage.repository.finishActiveSession(
                endDate: start.addingTimeInterval(TimeInterval(duration)),
                durationSeconds: duration
            )
        }

        let completed = try storage.repository.completedSessions()
        XCTAssertEqual(completed.map(\.durationSeconds), [61, 1_800, 3_600])
        XCTAssertEqual(try storage.repository.totalCompletedDurationSeconds(), 5_461)
    }

    @MainActor
    func testActiveSessionIsExcludedFromCompletedTotal() throws {
        let storage = try TestStorage.inMemory()
        _ = try storage.repository.createActiveSession(startDate: Date(timeIntervalSinceReferenceDate: 800_000_000))

        XCTAssertTrue(try storage.repository.completedSessions().isEmpty)
        XCTAssertEqual(try storage.repository.totalCompletedDurationSeconds(), 0)
    }

    @MainActor
    func testUpdatingDurationChangesTotalButKeepsEndDate() throws {
        let storage = try TestStorage.inMemory()
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let end = start.addingTimeInterval(7_200)
        _ = try storage.repository.createActiveSession(startDate: start)
        let finished = try storage.repository.finishActiveSession(endDate: end, durationSeconds: 7_200)

        let updated = try storage.repository.updateDuration(ofSessionWithID: finished.id, to: 1_234)

        XCTAssertEqual(updated.durationSeconds, 1_234)
        XCTAssertEqual(updated.startDate, start)
        XCTAssertEqual(updated.endDate, end)
        XCTAssertEqual(try storage.repository.totalCompletedDurationSeconds(), 1_234)
    }

    @MainActor
    func testUpdatingDurationValidatesInput() throws {
        let storage = try TestStorage.inMemory()
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let active = try storage.repository.createActiveSession(startDate: start)

        XCTAssertThrowsError(try storage.repository.updateDuration(ofSessionWithID: active.id, to: 600)) { error in
            XCTAssertEqual(error as? SessionError, .sessionIsActive)
        }
        XCTAssertThrowsError(try storage.repository.updateDuration(ofSessionWithID: UUID(), to: 600)) { error in
            XCTAssertEqual(error as? SessionError, .sessionNotFound)
        }

        let finished = try storage.repository.finishActiveSession(endDate: start.addingTimeInterval(600), durationSeconds: 600)
        XCTAssertThrowsError(try storage.repository.updateDuration(ofSessionWithID: finished.id, to: 59)) { error in
            XCTAssertEqual(error as? SessionError, .durationTooShort(59))
        }
        XCTAssertEqual(try storage.repository.totalCompletedDurationSeconds(), 600)
    }

    @MainActor
    func testFinishingValidatesDurationAndDates() throws {
        let storage = try TestStorage.inMemory()
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

        XCTAssertThrowsError(try storage.repository.finishActiveSession(endDate: start, durationSeconds: 60)) { error in
            XCTAssertEqual(error as? SessionError, .noActiveSession)
        }

        _ = try storage.repository.createActiveSession(startDate: start)
        XCTAssertThrowsError(try storage.repository.finishActiveSession(endDate: start.addingTimeInterval(30), durationSeconds: 30)) { error in
            XCTAssertEqual(error as? SessionError, .durationTooShort(30))
        }
        XCTAssertThrowsError(try storage.repository.finishActiveSession(endDate: start.addingTimeInterval(-60), durationSeconds: 60)) { error in
            XCTAssertEqual(error as? SessionError, .endDateBeforeStartDate)
        }
        XCTAssertNotNil(try storage.repository.activeSession())
    }

    @MainActor
    func testDeletingSessionRemovesIt() throws {
        let storage = try TestStorage.inMemory()
        let active = try storage.repository.createActiveSession(startDate: Date(timeIntervalSinceReferenceDate: 800_000_000))

        try storage.repository.deleteSession(id: active.id)

        XCTAssertTrue(try storage.allSessions().isEmpty)
        XCTAssertThrowsError(try storage.repository.deleteSession(id: active.id)) { error in
            XCTAssertEqual(error as? SessionError, .sessionNotFound)
        }
    }
}
