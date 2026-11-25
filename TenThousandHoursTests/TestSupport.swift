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
        case deleteAll
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

    func deleteAllSessions() throws {
        try failIfNeeded(.deleteAll)
        try wrapped.deleteAllSessions()
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

/// Файл хранилища так, как его видят приложение и виджет. Каждый «участник» получает свой `ModelContainer`
/// и свой `FileLockCoordinator` на общем файле блокировки. Всё это внутри одного тестового процесса:
/// раздельные контейнеры и контексты воспроизводятся, но это не тест настоящих отдельных процессов.
nonisolated struct SharedStoreFixture: Sendable {
    let storeURL: URL

    init() throws {
        storeURL = try makeTemporaryDirectory().appendingPathComponent("TenThousandHours.store")
        // Хранилище создаётся заранее, как это делает приложение при первом запуске.
        _ = try ModelContainerFactory.makeContainer(storeURL: storeURL)
    }

    var lock: FileLockCoordinator {
        FileLockCoordinator(lockFileURL: ModelContainerFactory.lockFileURL(forStoreAt: storeURL))
    }

    /// Отдельный участник (виджет, intent): свой контейнер на том же файле, тот же `TimerEngine`.
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
