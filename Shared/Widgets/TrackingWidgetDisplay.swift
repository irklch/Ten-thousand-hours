import Foundation

/// Widget state read from the shared store.
nonisolated enum TrackingWidgetState: Equatable, Sendable {
    case ready(TrackingStatus)
    /// The store cannot be read (App Group unavailable, SwiftData error). The widget then shows no
    /// Play/Stop and no progress instead of a made-up zero state.
    case unavailable
}

/// Text and state of the widget at a given moment. Formulas and formatting are the shared
/// `ProgressCalculator` / `ProgressFormatter`, so the numbers match the app.
nonisolated struct TrackingWidgetDisplay: Equatable, Sendable {
    enum Content: Equatable, Sendable {
        case ready(Ready)
        case unavailable
    }

    struct Ready: Equatable, Sendable {
        let isRunning: Bool
        let percentText: String
        let hoursText: String
        let percentAccessibilityLabel: String
        let hoursAccessibilityLabel: String

        var buttonAccessibilityLabel: String {
            isRunning
                ? String(localized: "Остановить отслеживание времени")
                : String(localized: "Начать отслеживание времени")
        }
    }

    let content: Content

    init(state: TrackingWidgetState, date: Date) {
        switch state {
        case .ready(let status):
            let progress = status.progress(at: date)
            content = .ready(Ready(
                isRunning: status.isRunning,
                percentText: ProgressFormatter.percent(progress),
                hoursText: ProgressFormatter.hours(progress),
                percentAccessibilityLabel: ProgressFormatter.spokenPercent(progress),
                hoursAccessibilityLabel: ProgressFormatter.spokenHours(progress)
            ))
        case .unavailable:
            content = .unavailable
        }
    }
}

/// Timeline plan. The widget has no per-second timer: WidgetKit shows ready-made entries itself.
///
/// - Timer stopped: progress does not change, one entry, no reloads (the app and the intents reload
///   the timeline after changes).
/// - Timer running: an entry every minute for an hour ahead (0,01 % is 36 seconds, so the percent
///   moves noticeably), then a new timeline. The system may show updates with a delay; continuous
///   per-second updating is not promised.
/// - Store unavailable: retry in 15 minutes.
nonisolated enum TrackingTimelinePlanner {
    static let runningStep: TimeInterval = 60
    static let runningEntryCount = 60
    static let unavailableRetryInterval: TimeInterval = 15 * 60

    enum Reload: Equatable {
        case never
        case atEnd
        case after(Date)
    }

    static func entryDates(for state: TrackingWidgetState, now: Date) -> [Date] {
        guard case .ready(let status) = state, status.isRunning else {
            return [now]
        }
        let nextMinute = (now.timeIntervalSinceReferenceDate / runningStep).rounded(.down) * runningStep + runningStep
        let following = (0..<runningEntryCount - 1).map {
            Date(timeIntervalSinceReferenceDate: nextMinute + Double($0) * runningStep)
        }
        return [now] + following
    }

    static func reload(for state: TrackingWidgetState, now: Date) -> Reload {
        switch state {
        case .ready(let status):
            status.isRunning ? .atEnd : .never
        case .unavailable:
            .after(now.addingTimeInterval(unavailableRetryInterval))
        }
    }
}

extension SharedTracking {
    /// The widget state. A read error turns into an explicit `unavailable` state; it is not hidden.
    static func widgetState() -> TrackingWidgetState {
        do {
            return .ready(try status())
        } catch {
            return .unavailable
        }
    }
}
