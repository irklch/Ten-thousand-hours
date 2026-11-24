import SwiftData
import XCTest
@testable import TenThousandHours

/// The single store: creation, reopening, unavailability and recovery.
final class SharedStoreTests: XCTestCase {
    private final class NoAppGroupFileManager: FileManager, @unchecked Sendable {
        override func containerURL(forSecurityApplicationGroupIdentifier groupIdentifier: String) -> URL? { nil }
    }

    func testSharedStoreLivesInAppGroupContainer() throws {
        let url: URL
        do {
            url = try ModelContainerFactory.sharedStoreURL()
        } catch SharedStoreError.appGroupUnavailable {
            throw XCTSkip("Сборка без подписи (CI): entitlement App Group не применён")
        }

        XCTAssertTrue(url.path.hasSuffix("Library/Application Support/TenThousandHours.store"), url.path)
        XCTAssertEqual(ModelContainerFactory.lockFileURL(forStoreAt: url).lastPathComponent, "TenThousandHours.lock")
    }

    func testUnavailableAppGroupThrowsInsteadOfFallingBack() {
        XCTAssertThrowsError(try ModelContainerFactory.sharedStoreURL(fileManager: NoAppGroupFileManager())) {
            XCTAssertEqual($0 as? SharedStoreError, .appGroupUnavailable)
        }
    }

    @MainActor
    func testFirstLaunchCreatesStore() throws {
        let storeURL = try makeTemporaryDirectory().appendingPathComponent("Nested/TenThousandHours.store")

        let store = try TrackingStore.open(storeURL: storeURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
        XCTAssertFalse(store.isRunning)
        XCTAssertEqual(store.totalSeconds, 0)
    }

    @MainActor
    func testReopeningKeepsSessionsAndRestoresActiveTimer() throws {
        let clock = TestClock()
        let storeURL = try makeTemporaryDirectory().appendingPathComponent("TenThousandHours.store")
        _ = try TrackingStore.open(storeURL: storeURL)
        let engine = TimerEngine(
            repository: SwiftDataSessionRepository(container: try ModelContainerFactory.makeContainer(storeURL: storeURL)),
            now: clock.provider()
        )
        try engine.start()
        clock.advance(by: 3_600)
        try engine.stop()
        try engine.start()

        let reopened = try TrackingStore.open(storeURL: storeURL)

        XCTAssertTrue(reopened.isRunning)
        XCTAssertEqual(try reopened.completedSessions().map(\.durationSeconds), [3_600])
    }

    @MainActor
    func testSwiftDataOpenErrorDoesNotReplaceExistingFile() throws {
        let storeURL = try makeTemporaryDirectory().appendingPathComponent("TenThousandHours.store")
        let garbage = Data("not a database".utf8)
        try garbage.write(to: storeURL)

        XCTAssertThrowsError(try TrackingStore.open(storeURL: storeURL))
        XCTAssertEqual(try Data(contentsOf: storeURL), garbage, "Существующий файл нельзя удалять или пересоздавать")
    }

    @MainActor
    func testStoreRecoversAfterTemporaryUnavailability() throws {
        let directory = try makeTemporaryDirectory()
        let blocker = directory.appendingPathComponent("Library")
        try Data().write(to: blocker)
        let storeURL = blocker.appendingPathComponent("TenThousandHours.store")

        XCTAssertThrowsError(try TrackingStore.open(storeURL: storeURL), "Папку хранилища создать нельзя")

        try FileManager.default.removeItem(at: blocker)
        let store = try TrackingStore.open(storeURL: storeURL)
        store.start()
        XCTAssertTrue(store.isRunning)
    }

    @MainActor
    func testWidgetReadsAppDataFromSameFile() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        let app = try fixture.appStore(now: clock.provider())

        app.start()

        XCTAssertEqual(try fixture.status(), TrackingStatus(activeSessionStartDate: clock.now, completedSessionsSeconds: 0))
    }
}

/// The logic of `StartTrackingIntent` / `StopTrackingIntent`: the intents call `TimerEngine` over the shared store.
final class TrackingIntentLogicTests: XCTestCase {
    @MainActor
    func testPlayCreatesActiveSession() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()

        let result = try fixture.engine(now: clock.provider()).start()

        guard case .started(let session) = result else { return XCTFail("Ожидался запуск, получено \(result)") }
        XCTAssertEqual(session.startDate, clock.now)
        XCTAssertEqual(try fixture.status(), TrackingStatus(activeSessionStartDate: clock.now, completedSessionsSeconds: 0))
    }

    @MainActor
    func testRepeatedPlayDoesNotCreateSecondSession() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()

        try fixture.engine(now: clock.provider()).start()
        clock.advance(by: 30)
        let second = try fixture.engine(now: clock.provider()).start()

        guard case .alreadyRunning = second else { return XCTFail("Повторный Play создал сессию: \(second)") }
        XCTAssertEqual(try fixture.allSessions().count, 1)
    }

    @MainActor
    func testStopAfterMinuteSavesSession() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        try fixture.engine(now: clock.provider()).start()
        clock.advance(by: 125.7)

        let result = try fixture.engine(now: clock.provider()).stop()

        guard case .saved(let session) = result else { return XCTFail("Ожидалось сохранение, получено \(result)") }
        XCTAssertEqual(session.durationSeconds, 125)
        XCTAssertEqual(try fixture.status(), TrackingStatus(activeSessionStartDate: nil, completedSessionsSeconds: 125))
    }

    @MainActor
    func testStopBeforeMinuteDiscardsSession() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        try fixture.engine(now: clock.provider()).start()
        clock.advance(by: 59)

        XCTAssertEqual(try fixture.engine(now: clock.provider()).stop(), .discardedTooShort)
        XCTAssertTrue(try fixture.allSessions().isEmpty)
    }

    @MainActor
    func testRepeatedStopIsSafe() throws {
        let clock = TestClock()
        let fixture = try SharedStoreFixture()
        try fixture.engine(now: clock.provider()).start()
        clock.advance(by: 120)
        try fixture.engine(now: clock.provider()).stop()
        clock.advance(by: 120)

        XCTAssertEqual(try fixture.engine(now: clock.provider()).stop(), .notRunning)
        XCTAssertEqual(try fixture.allSessions().map(\.durationSeconds), [120])
    }
}
