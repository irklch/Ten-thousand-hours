import Foundation
import SwiftData

final class SwiftDataSessionRepository: SessionRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func activeSession() throws -> SessionSnapshot? {
        try fetchActiveSession()?.snapshot
    }

    func createActiveSession(startDate: Date) throws -> SessionSnapshot {
        guard try fetchActiveSession() == nil else {
            throw SessionError.activeSessionAlreadyExists
        }
        let session = Session(startDate: startDate)
        context.insert(session)
        try save()
        return session.snapshot
    }

    func finishActiveSession(endDate: Date, durationSeconds: Int) throws -> SessionSnapshot {
        try SessionRules.validateCompletedDuration(durationSeconds)
        guard let session = try fetchActiveSession() else {
            throw SessionError.noActiveSession
        }
        guard endDate >= session.startDate else {
            throw SessionError.endDateBeforeStartDate
        }
        session.endDate = endDate
        session.durationSeconds = durationSeconds
        try save()
        return session.snapshot
    }

    func deleteSession(id: UUID) throws {
        guard let session = try fetchSession(id: id) else {
            throw SessionError.sessionNotFound
        }
        context.delete(session)
        try save()
    }

    func completedSessions() throws -> [SessionSnapshot] {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.endDate != nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try context.fetch(descriptor).map(\.snapshot)
    }

    func totalCompletedDurationSeconds() throws -> Int {
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.endDate != nil })
        descriptor.propertiesToFetch = [\.durationSeconds]
        return try context.fetch(descriptor).reduce(0) { $0 + ($1.durationSeconds ?? 0) }
    }

    func updateDuration(ofSessionWithID id: UUID, to durationSeconds: Int) throws -> SessionSnapshot {
        try SessionRules.validateCompletedDuration(durationSeconds)
        guard let session = try fetchSession(id: id) else {
            throw SessionError.sessionNotFound
        }
        guard session.endDate != nil else {
            throw SessionError.sessionIsActive
        }
        session.durationSeconds = durationSeconds
        try save()
        return session.snapshot
    }

    private func fetchActiveSession() throws -> Session? {
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.endDate == nil },
            sortBy: [SortDescriptor(\.startDate)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchSession(id: UUID) throws -> Session? {
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
