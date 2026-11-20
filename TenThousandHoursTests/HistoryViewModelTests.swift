import XCTest
@testable import TenThousandHours

final class HistoryViewModelTests: XCTestCase {
    @MainActor
    private func makeStore(storage: TestStorage, clock: TestClock, repository: (any SessionRepository)? = nil) -> TrackingStore {
        let store = TrackingStore(repository: repository ?? storage.repository, now: clock.provider())
        store.restore()
        return store
    }

    @MainActor
    private func addSession(_ store: TrackingStore, clock: TestClock, seconds: TimeInterval, gap: TimeInterval = 600) {
        store.start()
        clock.advance(by: seconds)
        store.stop()
        clock.advance(by: gap)
    }

    @MainActor
    func testEmptyHistory() throws {
        let storage = try TestStorage.inMemory()
        let viewModel = HistoryViewModel(store: makeStore(storage: storage, clock: TestClock()))

        viewModel.reload()

        XCTAssertTrue(viewModel.isEmpty)
        XCTAssertNil(viewModel.loadError)
    }

    @MainActor
    func testSingleCompletedSession() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let store = makeStore(storage: storage, clock: clock)
        let startDate = clock.now
        addSession(store, clock: clock, seconds: 9_294)
        let viewModel = HistoryViewModel(store: store)

        viewModel.reload()

        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.items[0].durationText, "2 ч 34 мин")
        XCTAssertEqual(viewModel.items[0].session.startDate, startDate)
        XCTAssertEqual(viewModel.items[0].dateText, SessionDateFormatter.format(startDate))
        XCTAssertEqual(viewModel.items[0].accessibilityLabel, "2 часа 34 минуты, \(SessionDateFormatter.format(startDate))")
    }

    @MainActor
    func testSessionsAreSortedNewestFirstAndActiveIsExcluded() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let store = makeStore(storage: storage, clock: clock)
        addSession(store, clock: clock, seconds: 3_600)
        addSession(store, clock: clock, seconds: 120)
        addSession(store, clock: clock, seconds: 5_400)
        store.start()
        clock.advance(by: 7_200)
        let viewModel = HistoryViewModel(store: store)

        viewModel.reload()

        XCTAssertEqual(viewModel.items.map(\.durationText), ["1 ч 30 мин", "2 мин", "1 ч"])
        XCTAssertTrue(viewModel.items.allSatisfy { !$0.session.isActive })
        let starts = viewModel.items.map(\.session.startDate)
        XCTAssertEqual(starts, starts.sorted(by: >))
    }

    @MainActor
    func testStoppedSessionAppearsAndRevisionChanges() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let store = makeStore(storage: storage, clock: clock)
        let viewModel = HistoryViewModel(store: store)
        viewModel.reload()
        let revision = store.sessionsRevision

        addSession(store, clock: clock, seconds: 600)

        XCTAssertGreaterThan(store.sessionsRevision, revision)
        viewModel.reload()
        XCTAssertEqual(viewModel.items.map(\.durationText), ["10 мин"])
    }

    @MainActor
    func testTimerTicksDoNotChangeHistoryRevision() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let store = makeStore(storage: storage, clock: clock)
        store.start()
        let revision = store.sessionsRevision

        for _ in 0..<5 {
            clock.advance(by: 1)
            store.refresh()
        }

        XCTAssertEqual(store.sessionsRevision, revision)
    }

    @MainActor
    func testEditingTargetsTappedSession() throws {
        let storage = try TestStorage.inMemory()
        let clock = TestClock()
        let store = makeStore(storage: storage, clock: clock)
        addSession(store, clock: clock, seconds: 600)
        let viewModel = HistoryViewModel(store: store)
        viewModel.reload()

        viewModel.edit(viewModel.items[0])

        XCTAssertEqual(viewModel.editedSession, viewModel.items[0].session)
    }
}
