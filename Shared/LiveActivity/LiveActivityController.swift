import ActivityKit
import Foundation
import os

/// Приводит Live Activities приложения в соответствие с активной сессией в SwiftData.
/// Своего состояния нет: каждый вызов читает `Activity.activities` и решает заново.
/// `nonisolated`: `Activity` не `Sendable`, поэтому она читается и завершается в одном домене изоляции.
nonisolated enum LiveActivityController {
    private static let logger = Logger(subsystem: "com.irklch.TenThousandHours", category: "LiveActivity")

    /// - Нет активной сессии: завершить все activity.
    /// - Есть активная сессия: оставить одну activity для этой сессии, завершить остальные (дубли, устаревшие)
    ///   и запросить новую, если не осталось ни одной.
    ///
    /// ActivityKit может отказать в запросе (Live Activities выключены, достигнут системный лимит или
    /// вызов пришёл из процесса, которому нельзя запускать activity). Сессия уже сохранена, поэтому
    /// отказ записывается в лог, а таймер продолжает работать в приложении и в виджетах.
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

    /// Сессия сохранена, но её состояние не удалось прочитать обратно, чтобы обновить Live Activity.
    /// Следующий запуск или возврат в приложение снова приведёт её в соответствие.
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

/// Что делать с существующими activity. Чистая функция, вынесена отдельно, чтобы её можно было тестировать без ActivityKit.
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
