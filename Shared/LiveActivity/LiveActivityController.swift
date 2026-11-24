import ActivityKit
import Foundation
import os

/// Brings the app's Live Activities into line with the active session in SwiftData.
/// It has no state of its own: every call reads `Activity.activities` and decides again.
/// `nonisolated`: `Activity` is not `Sendable`, so it is read and ended in one isolation domain.
nonisolated enum LiveActivityController {
    private static let logger = Logger(subsystem: "com.irklch.TenThousandHours", category: "LiveActivity")

    /// - No active session: end every activity.
    /// - Active session: keep one activity for this session, end the others (duplicates, stale ones),
    ///   and request a new one if none is left.
    ///
    /// ActivityKit can refuse a request (Live Activities are turned off, the system limit is reached, or the
    /// call came from a process that may not start activities). The session is already saved, so the
    /// refusal is logged and the timer keeps working in the app and in the widgets.
    static func sync(activeSession: SessionSnapshot?) async {
        let activities = Activity<TrackingActivityAttributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }
        let plan = LiveActivityPlan.make(
            activeSessionID: activeSession?.id,
            activities: activities.map { .init(id: $0.id, sessionID: $0.attributes.sessionID) }
        )
        for activity in activities where plan.activityIDsToEnd.contains(activity.id) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        if plan.shouldRequest, let activeSession {
            request(for: activeSession)
        }
    }

    /// The session was saved, but its state could not be read back to update the Live Activity.
    /// The next launch or return to the app reconciles it again.
    static func logSyncFailure(_ error: any Error) {
        logger.error("Live Activity sync skipped: \(error.localizedDescription, privacy: .public)")
    }

    private static func request(for session: SessionSnapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.info("Live Activities are turned off; the timer runs without them")
            return
        }
        do {
            _ = try Activity.request(
                attributes: TrackingActivityAttributes(sessionID: session.id, startDate: session.startDate),
                content: ActivityContent(state: .init(), staleDate: nil)
            )
        } catch {
            logger.error("ActivityKit refused to start a Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// What to do with the existing activities. A pure function, kept apart so it can be tested without ActivityKit.
nonisolated struct LiveActivityPlan: Equatable {
    struct ExistingActivity: Equatable {
        let id: String
        let sessionID: UUID
    }

    let activityIDsToEnd: [String]
    let shouldRequest: Bool

    static func make(activeSessionID: UUID?, activities: [ExistingActivity]) -> LiveActivityPlan {
        guard let activeSessionID else {
            return LiveActivityPlan(activityIDsToEnd: activities.map(\.id), shouldRequest: false)
        }
        let kept = activities.first { $0.sessionID == activeSessionID }
        return LiveActivityPlan(
            activityIDsToEnd: activities.filter { $0.id != kept?.id }.map(\.id),
            shouldRequest: kept == nil
        )
    }
}
