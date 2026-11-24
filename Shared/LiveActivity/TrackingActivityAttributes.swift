import ActivityKit
import Foundation

/// The Live Activity for the current session. It is only a view of the active session in SwiftData:
/// the session ID and `startDate` are fixed for the activity's whole life, so `ContentState` is empty,
/// and the duration is computed by the system from `startDate` (`Text(timerInterval:)`).
nonisolated struct TrackingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {}

    let sessionID: UUID
    let startDate: Date
}
