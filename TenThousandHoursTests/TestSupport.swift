import Foundation
import SwiftData
@testable import TenThousandHours

@MainActor
final class TestClock {
    var now: Date

    init(_ now: Date = Date(timeIntervalSinceReferenceDate: 800_000_000)) {
        self.now = now
    }

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }

    func provider() -> () -> Date {
        { self.now }
    }
}

@MainActor
struct TestStorage {
    let container: ModelContainer
    let repository: SwiftDataSessionRepository

    init(container: ModelContainer) {
        self.container = container
        self.repository = SwiftDataSessionRepository(context: ModelContext(container))
    }

    static func inMemory() throws -> TestStorage {
        TestStorage(container: try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true))
    }

    static func onDisk(at url: URL) throws -> TestStorage {
        TestStorage(container: try ModelContainerFactory.makeContainer(storeURL: url))
    }

    func allSessions() throws -> [Session] {
        try ModelContext(container).fetch(FetchDescriptor<Session>())
    }
}

struct InjectedSaveError: Error, Equatable {}

final class FailingSessionRepository: SessionRepository {
    enum Operation {
        case create
        case finish
        case delete
        case total
        case update
    }

    var failingOperations: Set<Operation> = []
    private let wrapped: any SessionRepository

    init(wrapping wrapped: any SessionRepository) {
        self.wrapped = wrapped
    }

    func activeSession() throws -> SessionSnapshot? {
        try wrapped.activeSession()
    }

    func createActiveSession(startDate: Date) throws -> SessionSnapshot {
        try failIfNeeded(.create)
        return try wrapped.createActiveSession(startDate: startDate)
    }

    func finishActiveSession(endDate: Date, durationSeconds: Int) throws -> SessionSnapshot {
        try failIfNeeded(.finish)
        return try wrapped.finishActiveSession(endDate: endDate, durationSeconds: durationSeconds)
    }

    func deleteSession(id: UUID) throws {
        try failIfNeeded(.delete)
        try wrapped.deleteSession(id: id)
    }

    func completedSessions() throws -> [SessionSnapshot] {
        try wrapped.completedSessions()
    }

    func totalCompletedDurationSeconds() throws -> Int {
        try failIfNeeded(.total)
        return try wrapped.totalCompletedDurationSeconds()
    }

    func updateDuration(ofSessionWithID id: UUID, to durationSeconds: Int) throws -> SessionSnapshot {
        try failIfNeeded(.update)
        return try wrapped.updateDuration(ofSessionWithID: id, to: durationSeconds)
    }

    private func failIfNeeded(_ operation: Operation) throws {
        if failingOperations.contains(operation) {
            throw InjectedSaveError()
        }
    }
}

func makeTemporaryStoreURL() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("TenThousandHoursTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appendingPathComponent("Sessions.store")
}

func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("TenThousandHoursTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

/// A store file as the app and the widget see it. Each "participant" gets its own `ModelContainer`
/// and its own `FileLockCoordinator` on the shared lock file. This is all inside one test process:
/// it reproduces the separate containers and contexts, but it is not a test of real separate processes.
nonisolated struct SharedStoreFixture: Sendable {
    let storeURL: URL

    init() throws {
        storeURL = try makeTemporaryDirectory().appendingPathComponent("TenThousandHours.store")
        // The store is created in advance, as the app does on first launch.
        _ = try ModelContainerFactory.makeContainer(storeURL: storeURL)
    }

    var lock: FileLockCoordinator {
        FileLockCoordinator(lockFileURL: ModelContainerFactory.lockFileURL(forStoreAt: storeURL))
    }

    /// A separate participant (widget, intent): its own container on the same file, the same `TimerEngine`.
    func engine(now: @escaping () -> Date = Date.init) throws -> TimerEngine {
        TimerEngine(repository: try repository(), lock: lock, now: now)
    }

    func status() throws -> TrackingStatus {
        try TrackingStatus.read(from: try repository(), lock: lock)
    }

    func repository() throws -> SwiftDataSessionRepository {
        SwiftDataSessionRepository(container: try ModelContainerFactory.makeContainer(storeURL: storeURL))
    }

    @MainActor
    func appStore(now: @escaping () -> Date, onSessionsChanged: @escaping () -> Void = {}) throws -> TrackingStore {
        TrackingStore(repository: try repository(), lock: lock, onSessionsChanged: onSessionsChanged, now: now)
    }

    func allSessions() throws -> [SessionSnapshot] {
        let container = try ModelContainerFactory.makeContainer(storeURL: storeURL)
        return try ModelContext(container).fetch(FetchDescriptor<Session>()).map(\.snapshot)
    }
}
