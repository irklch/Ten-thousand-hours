#if DEBUG
import Foundation

enum UITestingStore {
    static let enableArgument = "-ui-testing"
    static let resetArgument = "-ui-testing-reset"
    static let seedHoursArgument = "-ui-testing-seed-hours"

    static func storeURLIfRequested(arguments: [String] = ProcessInfo.processInfo.arguments) throws -> URL? {
        guard arguments.contains(enableArgument) else { return nil }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("UITesting", isDirectory: true)
        if arguments.contains(resetArgument), FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Sessions.store")
    }

    static func seedIfRequested(
        repository: any SessionRepository,
        now: Date = Date(),
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) throws {
        guard arguments.contains(enableArgument),
              let index = arguments.firstIndex(of: seedHoursArgument),
              arguments.indices.contains(index + 1),
              let hours = Int(arguments[index + 1]), hours > 0,
              try repository.completedSessions().isEmpty,
              try repository.activeSession() == nil
        else { return }

        let duration = hours * ProgressGoal.secondsPerHour
        let endDate = SessionRules.wholeSeconds(now)
        _ = try repository.createActiveSession(startDate: endDate.addingTimeInterval(-TimeInterval(duration)))
        _ = try repository.finishActiveSession(endDate: endDate, durationSeconds: duration)
    }
}
#endif
