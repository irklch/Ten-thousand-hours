import Foundation

nonisolated enum SessionRules {
    static let minimumDurationSeconds = 60

    static func wholeSeconds(_ date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate.rounded(.down))
    }

    static func elapsedSeconds(from startDate: Date, to endDate: Date) -> Int {
        max(0, Int(endDate.timeIntervalSince(startDate).rounded(.down)))
    }

    static func validateCompletedDuration(_ seconds: Int) throws(SessionError) {
        guard seconds >= minimumDurationSeconds else {
            throw .durationTooShort(seconds)
        }
    }
}

nonisolated enum SessionError: LocalizedError, Equatable {
    case activeSessionAlreadyExists
    case noActiveSession
    case sessionNotFound
    case sessionIsActive
    case endDateBeforeStartDate
    case durationTooShort(Int)
    case goalCompleted
    case goalNotCompleted

    var errorDescription: String? {
        switch self {
        case .activeSessionAlreadyExists:
            String(localized: "Сессия уже запущена")
        case .noActiveSession:
            String(localized: "Нет активной сессии")
        case .sessionNotFound:
            String(localized: "Сессия не найдена")
        case .sessionIsActive:
            String(localized: "Нельзя изменить активную сессию")
        case .endDateBeforeStartDate:
            String(localized: "Время завершения раньше времени начала")
        case .durationTooShort:
            String(localized: "Продолжительность сессии должна быть не меньше минуты")
        case .goalCompleted:
            String(localized: "Цель 10 000 часов достигнута. Чтобы продолжить, начните заново.")
        case .goalNotCompleted:
            String(localized: "Начать заново можно только после 10 000 часов")
        }
    }
}
