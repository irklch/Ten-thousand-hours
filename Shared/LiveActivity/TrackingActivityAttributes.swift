import ActivityKit
import Foundation

/// Live Activity текущей сессии. Это только отображение активной сессии из SwiftData:
/// ID сессии и `startDate` не меняются за всё время жизни activity, поэтому `ContentState` пустой,
/// а длительность система считает сама от `startDate` (`Text(timerInterval:)`).
nonisolated struct TrackingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {}

    let sessionID: UUID
    let startDate: Date
}
