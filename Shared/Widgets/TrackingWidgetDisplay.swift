import Foundation

/// Состояние виджета, прочитанное из общего хранилища.
nonisolated enum TrackingWidgetState: Equatable, Sendable {
    case ready(TrackingStatus)
    /// Хранилище не читается (App Group недоступна, ошибка SwiftData). Тогда виджет не показывает
    /// Play/Stop и прогресс вместо выдуманного нулевого состояния.
    case unavailable
}

/// Текст и состояние виджета в заданный момент. Формулы и форматирование — общие
/// `ProgressCalculator` / `ProgressFormatter`, поэтому цифры совпадают с приложением.
nonisolated struct TrackingWidgetDisplay: Equatable, Sendable {
    enum Content: Equatable, Sendable {
        case ready(Ready)
        case unavailable
    }

    struct Ready: Equatable, Sendable {
        let isRunning: Bool
        /// Цель достигнута и таймер не идёт: вместо Play — отметка без действия, новый цикл начинается в приложении.
        let isGoalCompleted: Bool
        let percentText: String
        let hoursText: String
        let percentAccessibilityLabel: String
        let hoursAccessibilityLabel: String

        var buttonAccessibilityLabel: String {
            if isGoalCompleted {
                return String(localized: "Цель 10 000 часов достигнута")
            }
            return isRunning
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
                isGoalCompleted: status.isGoalCompleted && !status.isRunning,
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

/// План таймлайна. У виджета нет посекундного таймера: WidgetKit сам показывает готовые записи.
///
/// - Таймер остановлен: прогресс не меняется, одна запись, без перезагрузок (приложение и intents перезагружают
///   таймлайн после изменений).
/// - Таймер идёт: запись каждую минуту на час вперёд (0,01 % — это 36 секунд, так что процент
///   заметно движется), затем новый таймлайн. Система может показывать обновления с задержкой; непрерывное
///   посекундное обновление не обещается.
/// - Хранилище недоступно: повтор через 15 минут.
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
    /// Состояние виджета. Ошибка чтения превращается в явное состояние `unavailable` и не скрывается.
    static func widgetState() -> TrackingWidgetState {
        do {
            return .ready(try status())
        } catch {
            return .unavailable
        }
    }
}
