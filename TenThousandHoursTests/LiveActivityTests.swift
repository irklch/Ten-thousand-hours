import XCTest
@testable import TenThousandHours

final class LiveActivityPlanTests: XCTestCase {
    private let sessionID = UUID()

    func testPlayWithoutActivityRequestsOne() {
        let plan = LiveActivityPlan.make(activeSessionID: sessionID, activities: [])
        XCTAssertEqual(plan, LiveActivityPlan(activityIDsToEnd: [], shouldRequest: true))
    }

    func testRepeatedPlayKeepsTheExistingActivity() {
        let plan = LiveActivityPlan.make(activeSessionID: sessionID, activities: [.init(id: "a", sessionID: sessionID)])
        XCTAssertEqual(plan, LiveActivityPlan(activityIDsToEnd: [], shouldRequest: false))
    }

    func testStopEndsEveryActivity() {
        let plan = LiveActivityPlan.make(
            activeSessionID: nil,
            activities: [.init(id: "a", sessionID: sessionID), .init(id: "b", sessionID: UUID())]
        )
        XCTAssertEqual(plan, LiveActivityPlan(activityIDsToEnd: ["a", "b"], shouldRequest: false))
    }

    func testDuplicatesAndStaleSessionsAreEndedLeavingOne() {
        let plan = LiveActivityPlan.make(
            activeSessionID: sessionID,
            activities: [
                .init(id: "old", sessionID: UUID()),
                .init(id: "a", sessionID: sessionID),
                .init(id: "duplicate", sessionID: sessionID),
            ]
        )
        XCTAssertEqual(plan, LiveActivityPlan(activityIDsToEnd: ["old", "duplicate"], shouldRequest: false))
    }

    func testActivityOfAnOldSessionIsReplaced() {
        let plan = LiveActivityPlan.make(activeSessionID: sessionID, activities: [.init(id: "old", sessionID: UUID())])
        XCTAssertEqual(plan, LiveActivityPlan(activityIDsToEnd: ["old"], shouldRequest: true))
    }
}

final class TrackingStoreLiveActivityTests: XCTestCase {
    /// После каждой операции store сообщает сессию, которая лежит в SwiftData; Live Activity следует за ней.
    @MainActor
    func testActiveSessionIsReportedAfterRestorePlayAndStop() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        var reported: [SessionSnapshot?] = []
        let store = TrackingStore(
            repository: storage.repository,
            onActiveSessionRead: { reported.append($0) },
            now: clock.provider()
        )

        let startDate = clock.now
        store.restore()
        store.start()
        store.start()
        clock.advance(by: 120)
        store.stop()

        XCTAssertEqual(reported.count, 4)
        XCTAssertNil(reported[0] ?? nil)
        let started = try XCTUnwrap(reported[1] ?? nil)
        XCTAssertEqual(started.startDate, startDate)
        XCTAssertEqual(reported[2] ?? nil, started, "a repeated Play reports the same session")
        XCTAssertNil(reported[3] ?? nil)
    }

    /// Если store падает, ничего не сообщается: неудачная операция не меняет Live Activity.
    @MainActor
    func testFailedPlayReportsNothing() throws {
        let repository = FailingSessionRepository(wrapping: try TestStorage.inMemory().repository)
        repository.failingOperations = [.create]
        var reported: [SessionSnapshot?] = []
        let store = TrackingStore(
            repository: repository,
            onActiveSessionRead: { reported.append($0) }
        )

        store.start()

        XCTAssertNotNil(store.error)
        XCTAssertTrue(reported.isEmpty)
    }
}
