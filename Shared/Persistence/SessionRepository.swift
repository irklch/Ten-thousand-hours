import Foundation

protocol SessionRepository {
    func activeSession() throws -> SessionSnapshot?
    func createActiveSession(startDate: Date) throws -> SessionSnapshot
    func finishActiveSession(endDate: Date, durationSeconds: Int) throws -> SessionSnapshot
    func deleteSession(id: UUID) throws
    func completedSessions() throws -> [SessionSnapshot]
    func totalCompletedDurationSeconds() throws -> Int
    func updateDuration(ofSessionWithID id: UUID, to durationSeconds: Int) throws -> SessionSnapshot
}
