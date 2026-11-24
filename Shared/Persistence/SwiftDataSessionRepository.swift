import Foundation
import SwiftData

nonisolated final class SwiftDataSessionRepository: SessionRepository {
    private let makeContext: () -> ModelContext

    /// Один общий контекст: только для хранилищ в памяти (тесты, Preview).
    init(context: ModelContext) {
        makeContext = { context }
    }

    /// Каждая операция получает новый `ModelContext` и поэтому читает актуальное содержимое хранилища,
    /// включая изменения из другого процесса (Play/Stop из виджета).
    init(container: ModelContainer) {
        makeContext = {
            let context = ModelContext(container)
            context.autosaveEnabled = false
            return context
        }
    }

    nonisolated deinit {}

    func activeSession() throws -> SessionSnapshot? {
        try fetchActiveSession(in: makeContext())?.snapshot
    }

    func createActiveSession(startDate: Date) throws -> SessionSnapshot {
        let context = makeContext()
        guard try fetchActiveSession(in: context) == nil else {
            throw SessionError.activeSessionAlreadyExists
        }
        let session = Session(startDate: startDate)
        context.insert(session)
        try save(context)
        return session.snapshot
    }

    func finishActiveSession(endDate: Date, durationSeconds: Int) throws -> SessionSnapshot {
        try SessionRules.validateCompletedDuration(durationSeconds)
        let context = makeContext()
        guard let session = try fetchActiveSession(in: context) else {
            throw SessionError.noActiveSession
        }
        guard endDate >= session.startDate else {
            throw SessionError.endDateBeforeStartDate
        }
        session.endDate = endDate
        session.durationSeconds = durationSeconds
        try save(context)
        return session.snapshot
    }

    func deleteSession(id: UUID) throws {
        let context = makeContext()
        guard let session = try fetchSession(id: id, in: context) else {
            throw SessionError.sessionNotFound
        }
        context.delete(session)
        try save(context)
    }

    func completedSessions() throws -> [SessionSnapshot] {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.endDate != nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try makeContext().fetch(descriptor).map(\.snapshot)
    }

    func totalCompletedDurationSeconds() throws -> Int {
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.endDate != nil })
        descriptor.propertiesToFetch = [\.durationSeconds]
        return try makeContext().fetch(descriptor).reduce(0) { $0 + ($1.durationSeconds ?? 0) }
    }

    func updateDuration(ofSessionWithID id: UUID, to durationSeconds: Int) throws -> SessionSnapshot {
        try SessionRules.validateCompletedDuration(durationSeconds)
        let context = makeContext()
        guard let session = try fetchSession(id: id, in: context) else {
            throw SessionError.sessionNotFound
        }
        guard session.endDate != nil else {
            throw SessionError.sessionIsActive
        }
        session.durationSeconds = durationSeconds
        try save(context)
        return session.snapshot
    }

    private func fetchActiveSession(in context: ModelContext) throws -> Session? {
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.endDate == nil },
            sortBy: [SortDescriptor(\.startDate)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchSession(id: UUID, in context: ModelContext) throws -> Session? {
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func save(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
