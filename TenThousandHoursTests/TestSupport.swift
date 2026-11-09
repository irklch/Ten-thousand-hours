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

@MainActor
final class FailingSessionRepository: SessionRepository {
    enum Operation {
        case create
        case finish
        case delete
        case total
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
        try wrapped.updateDuration(ofSessionWithID: id, to: durationSeconds)
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
