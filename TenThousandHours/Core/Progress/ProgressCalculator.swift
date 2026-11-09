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
        let totalSeconds = max(0, completedSessionsSeconds) + max(0, activeSessionSeconds)
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
