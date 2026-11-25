import Foundation

nonisolated enum ProgressGoal {
    static let targetHours = 10_000
    static let secondsPerHour = 3_600
    static let targetSeconds = targetHours * secondsPerHour
}

nonisolated struct ProgressSnapshot: Equatable, Sendable {
    let totalSeconds: Int
    let completedHours: Int
    let progressPercent: Double
    let filledDotCount: Int
    let goalReached: Bool
}

nonisolated enum ProgressCalculator {
    static func progress(completedSessionsSeconds: Int, activeSessionSeconds: Int) -> ProgressSnapshot {
        let totalSeconds = saturatingSum(max(0, completedSessionsSeconds), max(0, activeSessionSeconds))
        let completedHours = totalSeconds / ProgressGoal.secondsPerHour
        let percent = Double(totalSeconds) / Double(ProgressGoal.targetSeconds) * 100

        return ProgressSnapshot(
            totalSeconds: totalSeconds,
            completedHours: completedHours,
            progressPercent: min(percent, 100),
            filledDotCount: min(completedHours, ProgressGoal.targetHours),
            goalReached: totalSeconds >= ProgressGoal.targetSeconds
        )
    }

    /// Сумма длительностей без переполнения `Int`: отредактированные сессии могут быть очень длинными,
    /// а сумма выше `Int.max` всё равно означает выполненную цель.
    static func saturatingSum(_ lhs: Int, _ rhs: Int) -> Int {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? (rhs > 0 ? .max : .min) : sum
    }

    /// Цель завершена, когда завершённые сессии в сумме дают не меньше 10 000 часов.
    /// Идущая сессия не учитывается: её время ещё может быть отброшено или изменено.
    static func isGoalCompleted(completedSessionsSeconds: Int) -> Bool {
        progress(completedSessionsSeconds: completedSessionsSeconds, activeSessionSeconds: 0).goalReached
    }
}

nonisolated enum ProgressFormatter {
    static func percent(_ progress: ProgressSnapshot, locale: Locale = Locale(identifier: "ru_RU")) -> String {
        let cappedSeconds = min(progress.totalSeconds, ProgressGoal.targetSeconds)
        let hundredthsOfPercent = cappedSeconds * 10_000 / ProgressGoal.targetSeconds
        let value = Double(hundredthsOfPercent) / 100
        return value.formatted(.number.precision(.fractionLength(2)).locale(locale)) + "%"
    }

    static func hours(_ progress: ProgressSnapshot) -> String {
        "\(grouped(progress.completedHours)) / \(grouped(ProgressGoal.targetHours)) ч"
    }

    static func accessibilitySummary(_ progress: ProgressSnapshot) -> String {
        let hours = grouped(progress.completedHours)
        let goal = grouped(ProgressGoal.targetHours)
        return String(localized: "Прогресс: \(percent(progress)). Завершено часов: \(hours) из \(goal)")
    }

    /// «Выполнено 12,45 процента». Число с дробной частью требует родительного падежа единственного числа.
    static func spokenPercent(_ progress: ProgressSnapshot) -> String {
        let value = String(percent(progress).dropLast())
        return String(localized: "Выполнено \(value) процента")
    }

    /// «Накоплено 1 245 часов из 10 000».
    static func spokenHours(_ progress: ProgressSnapshot) -> String {
        let hours = progress.completedHours
        let goal = grouped(ProgressGoal.targetHours)
        let count = grouped(hours)
        return switch RussianPlural.category(hours) {
        case .one: String(localized: "Накоплен \(count) час из \(goal)")
        case .few: String(localized: "Накоплено \(count) часа из \(goal)")
        case .many: String(localized: "Накоплено \(count) часов из \(goal)")
        }
    }

    private static func grouped(_ value: Int) -> String {
        let digits = Array(String(max(0, value)))
        var groups: [String] = []
        var end = digits.count
        while end > 0 {
            let start = max(0, end - 3)
            groups.insert(String(digits[start..<end]), at: 0)
            end = start
        }
        return groups.joined(separator: "\u{00A0}")
    }
}

nonisolated enum RussianPlural {
    enum Category: Equatable {
        case one
        case few
        case many
    }

    static func category(_ value: Int) -> Category {
        let number = abs(value)
        let lastTwo = number % 100
        let last = number % 10
        if (11...14).contains(lastTwo) { return .many }
        switch last {
        case 1: return .one
        case 2...4: return .few
        default: return .many
        }
    }
}
