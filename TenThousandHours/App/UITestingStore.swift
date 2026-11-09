#if DEBUG
import Foundation

enum UITestingStore {
    static let enableArgument = "-ui-testing"
    static let resetArgument = "-ui-testing-reset"

    static func storeURLIfRequested(arguments: [String] = ProcessInfo.processInfo.arguments) throws -> URL? {
        guard arguments.contains(enableArgument) else { return nil }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("UITesting", isDirectory: true)
        if arguments.contains(resetArgument), FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Sessions.store")
    }
}
#endif
