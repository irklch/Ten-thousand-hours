import XCTest
@testable import TenThousandHours

/// The logic behind `StartTrackingIntent` / `StopTrackingIntent`: the intents call exactly these
/// commands on the shared store.
final class TrackingCommandsTests: XCTestCase {
    @MainActor
    func testPlayCreatesActiveSession() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        let widget = try fixture.process(now: clock.provider())

        let result = try widget.start()

        guard case .started(let session) = result else { return XCTFail("Ожидался запуск, получено \(result)") }
        XCTAssertEqual(session.startDate, clock.now)
        XCTAssertEqual(try widget.status(), TrackingStatus(activeSessionStartDate: clock.now, completedSessionsSeconds: 0))
    }

    @MainActor
    func testRepeatedPlayDoesNotCreateSecondSession() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        let widget = try fixture.process(now: clock.provider())

        try widget.start()
        clock.advance(by: 30)
        let second = try widget.start()

        guard case .alreadyRunning = second else { return XCTFail("Повторный Play создал сессию: \(second)") }
        XCTAssertEqual(try fixture.allSessions().count, 1)
    }

    @MainActor
    func testStopAfterMinuteSavesSession() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        let widget = try fixture.process(now: clock.provider())

        try widget.start()
        clock.advance(by: 125.7)
        let result = try widget.stop()

        guard case .saved(let session) = result else { return XCTFail("Ожидалось сохранение, получено \(result)") }
        XCTAssertEqual(session.durationSeconds, 125)
        XCTAssertEqual(try widget.status(), TrackingStatus(activeSessionStartDate: nil, completedSessionsSeconds: 125))
    }

    @MainActor
    func testStopBeforeMinuteDiscardsSession() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        let widget = try fixture.process(now: clock.provider())

        try widget.start()
        clock.advance(by: 59)

        XCTAssertEqual(try widget.stop(), .discardedTooShort)
        XCTAssertTrue(try fixture.allSessions().isEmpty)
    }

    @MainActor
    func testRepeatedStopIsSafe() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        let widget = try fixture.process(now: clock.provider())

        try widget.start()
        clock.advance(by: 120)
        try widget.stop()
        clock.advance(by: 120)

        XCTAssertEqual(try widget.stop(), .notRunning)
        let sessions = try fixture.allSessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.durationSeconds, 120)
    }

    @MainActor
    func testStopWithoutActiveSessionCreatesNothing() throws {
        let fixture = try SharedStoreFixture()
        let widget = try fixture.process(now: TestClock().provider())

        XCTAssertEqual(try widget.stop(), .notRunning)
        XCTAssertTrue(try fixture.allSessions().isEmpty)
    }

    @MainActor
    func testCommandsRefuseToWorkBeforeMigration() throws {
        let fixture = try SharedStoreFixture(migrated: false)

        XCTAssertThrowsError(try SharedTracking.commands(location: fixture.location)) { error in
            XCTAssertEqual(error as? SharedStoreError, .migrationPending)
        }
        XCTAssertEqual(SharedTracking.widgetState(location: fixture.location), .unavailable(.migrationPending))
    }

    @MainActor
    func testWidgetStateReadsSharedStore() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        let app = try fixture.process(now: clock.provider())
        try app.start()

        XCTAssertEqual(
            SharedTracking.widgetState(location: fixture.location),
            .ready(TrackingStatus(activeSessionStartDate: clock.now, completedSessionsSeconds: 0))
        )
    }
}
