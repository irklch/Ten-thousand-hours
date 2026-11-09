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
}
