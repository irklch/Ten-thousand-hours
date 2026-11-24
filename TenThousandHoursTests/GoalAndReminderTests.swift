import UserNotifications
import XCTest
@testable import TenThousandHours

/// Этап 8: напоминание в 20:00, достижение 10 000 часов и сброс. Время и календарь управляемые.
final class DailyReminderPlanTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 11) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func plan(now: Date, lastTracking: Date? = nil, isRunning: Bool = false, completed: Bool = false) -> [DateComponents] {
        DailyReminderPlan.fireDates(
            now: now,
            calendar: calendar,
            lastTrackingDate: lastTracking,
            isRunning: isRunning,
            isGoalCompleted: completed
        )
    }

    func testReminderIsPlannedForTodayAt20() {
        let dates = plan(now: date(24, 9))

        XCTAssertEqual(dates.count, DailyReminderPlan.dayCount)
        XCTAssertEqual(dates.first, DateComponents(year: 2026, month: 11, day: 24, hour: 20, minute: 0))
        XCTAssertEqual(dates[1].day, 25)
        XCTAssertNil(dates.first?.timeZone, "плавающее локальное время: при смене пояса срабатывает в 20:00 на месте")
    }

    func testPlayTodaySkipsOnlyTodaysReminder() {
        let dates = plan(now: date(24, 10), lastTracking: date(24, 9, 30))

        XCTAssertEqual(dates.first?.day, 25)
        XCTAssertEqual(dates.count, DailyReminderPlan.dayCount)
    }

    func testTrackingYesterdayDoesNotSkipToday() {
        XCTAssertEqual(plan(now: date(24, 10), lastTracking: date(23, 23, 59)).first?.day, 24)
    }

    func testRunningTimerAndPassedReminderTimeSkipToday() {
        XCTAssertEqual(plan(now: date(24, 10), isRunning: true).first?.day, 25)
        XCTAssertEqual(plan(now: date(24, 20)).first?.day, 25)
        XCTAssertEqual(plan(now: date(24, 19, 59)).first?.day, 24)
    }

    func testCompletedGoalCancelsReminders() {
        XCTAssertTrue(plan(now: date(24, 9), completed: true).isEmpty)
    }

    /// Переход на летнее время (29.03.2026 в Европе) не сдвигает напоминания.
    func testDaylightSavingTransitionKeepsLocal20() {
        let dates = plan(now: date(28, 21, month: 3))

        XCTAssertEqual(dates.prefix(3).map(\.day), [29, 30, 31])
        XCTAssertTrue(dates.allSatisfy { $0.hour == 20 && $0.minute == 0 })
    }

    func testIdentifiersAreUniquePerDay() {
        let identifiers = plan(now: date(24, 9)).map(DailyReminderScheduler.identifier(for:))
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
    }
}

final class GoalTrackingTests: XCTestCase {
    private let goal = ProgressGoal.targetSeconds

    @MainActor
    private func seed(_ storage: TestStorage, seconds: Int, clock: TestClock) throws -> SessionSnapshot {
        _ = try storage.repository.createActiveSession(startDate: clock.now.addingTimeInterval(-TimeInterval(seconds)))
        return try storage.repository.finishActiveSession(endDate: clock.now, durationSeconds: seconds)
    }

    // MARK: Напоминания и время последнего запуска

    @MainActor
    func testShortDiscardedSessionCountsAsTrackingToday() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let preferences = SharedPreferences.ephemeral()
        let engine = TimerEngine(repository: storage.repository, preferences: preferences, now: clock.provider())

        try engine.start()
        clock.advance(by: 10)
        XCTAssertEqual(try engine.stop(), .discardedTooShort)

        XCTAssertEqual(preferences.lastTrackingDate, clock.now)
        let dates = DailyReminderPlan.fireDates(
            now: clock.now,
            calendar: .current,
            lastTrackingDate: preferences.lastTrackingDate,
            isRunning: false,
            isGoalCompleted: false
        )
        let today = Calendar.current.dateComponents([.day], from: clock.now).day
        XCTAssertNotEqual(dates.first?.day, today)
    }

    // MARK: Достижение цели

    func testGoalCompletesAtExactlyTenThousandHours() {
        XCTAssertFalse(ProgressCalculator.isGoalCompleted(completedSessionsSeconds: goal - 1))
        XCTAssertTrue(ProgressCalculator.isGoalCompleted(completedSessionsSeconds: goal))
    }

    @MainActor
    func testExceedingGoalKeepsActualTimeAndCapsDisplay() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        _ = try seed(storage, seconds: goal + 7_200, clock: clock)
        let store = TrackingStore(repository: storage.repository, now: clock.provider())

        store.restore()

        XCTAssertTrue(store.isGoalCompleted)
        XCTAssertTrue(store.isCelebrationPending)
        XCTAssertEqual(store.totalSeconds, goal + 7_200)
        XCTAssertEqual(store.progress.progressPercent, 100)
        XCTAssertEqual(store.progress.filledDotCount, ProgressGoal.targetHours)
        XCTAssertEqual(try storage.repository.totalCompletedDurationSeconds(), goal + 7_200)
    }

    @MainActor
    func testStopAfterCrossingGoalCompletesIt() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        _ = try seed(storage, seconds: goal - 60, clock: clock)
        let store = TrackingStore(repository: storage.repository, now: clock.provider())
        store.restore()
        store.start()
        clock.advance(by: 120)
        store.refresh()
        XCTAssertFalse(store.isGoalCompleted, "идущая сессия не останавливается и не завершает цель сама")
        XCTAssertTrue(store.isRunning)

        store.stop()

        XCTAssertTrue(store.isGoalCompleted)
        XCTAssertEqual(store.totalSeconds, goal + 60)
    }

    @MainActor
    func testEditingHistoryCompletesAndUncompletesGoal() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let session = try seed(storage, seconds: 3_600, clock: clock)
        let store = TrackingStore(repository: storage.repository, now: clock.provider())
        store.restore()

        try store.updateDuration(ofSessionWithID: session.id, to: goal)
        XCTAssertTrue(store.isGoalCompleted)
        XCTAssertTrue(store.isCelebrationPending)
        store.dismissCelebration()

        try store.updateDuration(ofSessionWithID: session.id, to: goal - 60)
        XCTAssertFalse(store.isGoalCompleted)
        XCTAssertFalse(store.isCelebrationPending)

        store.start()
        XCTAssertTrue(store.isRunning, "после возврата в незавершённое состояние Play снова доступен")
        XCTAssertNil(store.error)
    }

    @MainActor
    func testCelebrationIsShownOncePerCycle() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        _ = try seed(storage, seconds: goal, clock: clock)
        let preferences = SharedPreferences.ephemeral()
        let store = TrackingStore(repository: storage.repository, preferences: preferences, now: clock.provider())
        store.restore()
        store.dismissCelebration()

        let relaunched = TrackingStore(repository: storage.repository, preferences: preferences, now: clock.provider())
        relaunched.restore()

        XCTAssertTrue(relaunched.isGoalCompleted)
        XCTAssertFalse(relaunched.isCelebrationPending)
    }

    // MARK: Запреты

    @MainActor
    func testPlayIsRejectedAfterGoalForEveryEntryPoint() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        _ = try seed(storage, seconds: goal, clock: clock)
        let engine = TimerEngine(repository: storage.repository, now: clock.provider())
        let store = TrackingStore(repository: storage.repository, now: clock.provider())

        XCTAssertThrowsError(try engine.start()) { XCTAssertEqual($0 as? SessionError, .goalCompleted) }
        store.start()

        XCTAssertFalse(store.isRunning)
        XCTAssertEqual(store.error as? SessionError, .goalCompleted)
        XCTAssertNil(try storage.repository.activeSession())
    }

    @MainActor
    func testEarlyResetIsRejected() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        _ = try seed(storage, seconds: goal - 1, clock: clock)
        let store = TrackingStore(repository: storage.repository, now: clock.provider())
        store.restore()

        store.resetProgress()

        XCTAssertEqual(store.error as? SessionError, .goalNotCompleted)
        XCTAssertEqual(try storage.repository.completedSessions().count, 1)
        XCTAssertEqual(store.totalSeconds, goal - 1)
    }

    @MainActor
    func testResetIsRejectedWhileSessionIsRunning() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        _ = try seed(storage, seconds: goal, clock: clock)
        _ = try storage.repository.createActiveSession(startDate: clock.now)
        let engine = TimerEngine(repository: storage.repository, now: clock.provider())

        XCTAssertThrowsError(try engine.resetCompletedGoal())
        XCTAssertEqual(try storage.allSessions().count, 2)
    }

    // MARK: Сброс

    /// «Отмена» в подтверждении не вызывает сброс: данные и состояние не меняются.
    @MainActor
    func testCancelledConfirmationChangesNothing() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        _ = try seed(storage, seconds: goal, clock: clock)
        let store = TrackingStore(repository: storage.repository, now: clock.provider())
        store.restore()
        let revision = store.sessionsRevision

        XCTAssertTrue(HomeViewModel(store: store).showsRestart)

        XCTAssertEqual(store.sessionsRevision, revision)
        XCTAssertTrue(store.isGoalCompleted)
        XCTAssertEqual(try storage.repository.completedSessions().count, 1)
    }

    @MainActor
    func testSuccessfulResetClearsProgressAndHistory() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        _ = try seed(storage, seconds: goal, clock: clock)
        _ = try seed(storage, seconds: 3_600, clock: clock)
        let preferences = SharedPreferences.ephemeral()
        var widgetReloads = 0
        var reported: [TrackingSyncState] = []
        let store = TrackingStore(
            repository: storage.repository,
            preferences: preferences,
            onSessionsChanged: { widgetReloads += 1 },
            onStateRead: { reported.append($0) },
            now: clock.provider()
        )
        store.restore()
        store.dismissCelebration()
        let revision = store.sessionsRevision

        store.resetProgress()

        XCTAssertNil(store.error)
        XCTAssertEqual(try storage.allSessions().count, 0)
        XCTAssertEqual(store.totalSeconds, 0)
        XCTAssertEqual(ProgressDisplay(progress: store.progress).percentText, "0,00%")
        XCTAssertEqual(store.progress.filledDotCount, 0)
        XCTAssertFalse(store.isRunning)
        XCTAssertFalse(store.isGoalCompleted)
        XCTAssertFalse(preferences.isGoalCelebrationShown)
        XCTAssertGreaterThan(store.sessionsRevision, revision)
        XCTAssertEqual(widgetReloads, 1)
        XCTAssertEqual(reported.last, TrackingSyncState(activeSession: nil, isGoalCompleted: false))

        store.start()
        XCTAssertTrue(store.isRunning)
    }

    @MainActor
    func testResetSaveFailureKeepsEverything() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        _ = try seed(storage, seconds: goal, clock: clock)
        let repository = FailingSessionRepository(wrapping: storage.repository)
        repository.failingOperations = [.deleteAll]
        let store = TrackingStore(repository: repository, now: clock.provider())
        store.restore()

        store.resetProgress()

        XCTAssertEqual(store.error as? InjectedSaveError, InjectedSaveError())
        XCTAssertTrue(store.isGoalCompleted)
        XCTAssertEqual(store.totalSeconds, goal)
        XCTAssertEqual(try storage.repository.completedSessions().count, 1)

        repository.failingOperations = []
        store.resetProgress()
        XCTAssertNil(store.error, "операцию можно повторить")
        XCTAssertEqual(store.totalSeconds, 0)
    }

    /// Сброс в файловом хранилище: удаление и сохранение одной транзакцией, файл базы остаётся тем же.
    @MainActor
    func testResetOnSharedStoreKeepsDatabaseFile() throws {
        let fixture = try SharedStoreFixture()
        let clock = TestClock()
        let repository = try fixture.repository()
        _ = try repository.createActiveSession(startDate: clock.now)
        _ = try repository.finishActiveSession(endDate: clock.now.addingTimeInterval(60), durationSeconds: goal)

        try fixture.engine(now: clock.provider()).resetCompletedGoal()

        XCTAssertTrue(try fixture.allSessions().isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.storeURL.path))
        XCTAssertFalse(try fixture.status().isGoalCompleted)
    }

    // MARK: Виджет

    func testWidgetShowsCompletedStateWithoutPlay() {
        let completed = TrackingWidgetDisplay(
            state: .ready(TrackingStatus(activeSessionStartDate: nil, completedSessionsSeconds: goal)),
            date: Date()
        )
        guard case .ready(let ready) = completed.content else { return XCTFail() }
        XCTAssertTrue(ready.isGoalCompleted)
        XCTAssertEqual(ready.percentText, "100,00%")

        let running = TrackingWidgetDisplay(
            state: .ready(TrackingStatus(activeSessionStartDate: Date(), completedSessionsSeconds: goal)),
            date: Date()
        )
        guard case .ready(let runningReady) = running.content else { return XCTFail() }
        XCTAssertFalse(runningReady.isGoalCompleted, "идущую сессию можно остановить из виджета")
    }
}
