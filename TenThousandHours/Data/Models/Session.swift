import Foundation
import SwiftData

@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var endDate: Date?
    var durationSeconds: Int?

    init(id: UUID = UUID(), startDate: Date) {
        self.id = id
        self.startDate = startDate
        self.endDate = nil
        self.durationSeconds = nil
    }

    nonisolated deinit {}

    var snapshot: SessionSnapshot {
        SessionSnapshot(id: id, startDate: startDate, endDate: endDate, durationSeconds: durationSeconds)
    }
}
