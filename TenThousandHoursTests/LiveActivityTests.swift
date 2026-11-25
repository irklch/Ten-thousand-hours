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
            onStateRead: { reported.append($0.activeSession) },
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
            onStateRead: { reported.append($0.activeSession) }
        )

        store.start()

        XCTAssertNotNil(store.error)
        XCTAssertTrue(reported.isEmpty)
    }
}

/// Очередь синхронизации Live Activity и напоминаний: более новое состояние всегда применяется последним,
/// даже если предыдущая операция приостанавливается дольше.
final class SerialTaskQueueTests: XCTestCase {
    @MainActor
    func testOperationsFinishInCallOrderEvenWhenEarlierOneIsSlower() async {
        let queue = SerialTaskQueue()
        var log: [String] = []

        let first = queue.enqueue {
            log.append("start-1")
            try? await Task.sleep(for: .milliseconds(50))
            log.append("end-1")
        }
        let second = queue.enqueue {
            log.append("start-2")
            log.append("end-2")
        }
        await first.value
        await second.value

        XCTAssertEqual(log, ["start-1", "end-1", "start-2", "end-2"])
    }
}
