import Foundation

nonisolated struct SessionSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let startDate: Date
    let endDate: Date?
    let durationSeconds: Int?

    var isActive: Bool { endDate == nil }
}
