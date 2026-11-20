import Foundation
import WidgetKit

nonisolated struct TrackingWidgetEntry: TimelineEntry, Sendable {
    let date: Date
    let state: TrackingWidgetState
}

/// Reads the state from the shared SwiftData store on every timeline request.
/// The app and the intents call `reloadTimelines` after every change, so the widget always works with
/// what is written to the store, not with a cache.
nonisolated struct TrackingTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrackingWidgetEntry {
        TrackingWidgetEntry(date: Date(), state: .ready(Self.sampleStatus))
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (TrackingWidgetEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task { @MainActor in
            completion(TrackingWidgetEntry(date: Date(), state: SharedTracking.widgetState()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<TrackingWidgetEntry>) -> Void) {
        Task { @MainActor in
            let now = Date()
            let state = SharedTracking.widgetState()
            let entries = TrackingTimelinePlanner.entryDates(for: state, now: now).map {
                TrackingWidgetEntry(date: $0, state: state)
            }
            let policy: TimelineReloadPolicy = switch TrackingTimelinePlanner.reload(for: state, now: now) {
            case .never: .never
            case .atEnd: .atEnd
            case .after(let date): .after(date)
            }
            completion(Timeline(entries: entries, policy: policy))
        }
    }

    /// Example for the widget gallery, matching the Figma mockup.
    private static let sampleStatus = TrackingStatus(
        activeSessionStartDate: nil,
        completedSessionsSeconds: 1_245 * ProgressGoal.secondsPerHour + 1_620
    )
}
