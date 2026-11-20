import Foundation

nonisolated struct SessionDurationInput: Equatable, Sendable {
    enum ValidationError: Error, Equatable, Sendable {
        case invalidHours
        case invalidMinutes
        case tooLarge
        case tooShort

        var message: String {
            switch self {
            case .invalidHours:
                String(localized: "Часы — целое неотрицательное число")
            case .invalidMinutes:
                String(localized: "Минуты — целое число от 0 до 59")
            case .tooLarge:
                String(localized: "Слишком большое значение")
            case .tooShort:
                String(localized: "Продолжительность должна быть не меньше 1 минуты")
            }
        }
    }

    var hours: String
    var minutes: String

    init(hours: String, minutes: String) {
        self.hours = hours
        self.minutes = minutes
    }

    init(durationSeconds: Int) {
        let components = SessionDurationFormatter.components(durationSeconds)
        self.init(hours: String(components.hours), minutes: String(components.minutes))
    }

    var result: Result<Int, ValidationError> {
        guard let hoursValue = Self.nonNegativeInteger(hours) else {
            return .failure(Self.isOnlyDigits(hours) ? .tooLarge : .invalidHours)
        }
        guard let minutesValue = Self.nonNegativeInteger(minutes), minutesValue <= 59 else {
            return .failure(.invalidMinutes)
        }
        let (hourSeconds, hoursOverflow) = hoursValue.multipliedReportingOverflow(by: 3_600)
        let (total, totalOverflow) = hourSeconds.addingReportingOverflow(minutesValue * 60)
        guard !hoursOverflow, !totalOverflow else {
            return .failure(.tooLarge)
        }
        guard total >= SessionRules.minimumDurationSeconds else {
            return .failure(.tooShort)
        }
        return .success(total)
    }

    var durationSeconds: Int? {
        if case .success(let seconds) = result {
            return seconds
        }
        return nil
    }

    private static func nonNegativeInteger(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard isOnlyDigits(trimmed) else { return nil }
        return Int(trimmed)
    }

    private static func isOnlyDigits(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed.allSatisfy { $0.isASCII && $0.isNumber }
    }
}
