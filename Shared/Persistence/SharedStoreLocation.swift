import Foundation

nonisolated enum AppGroup {
    /// Must match the `com.apple.security.application-groups` entitlement of both targets.
    static let identifier = "group.com.irklch.TenThousandHours"
}

/// Files of the shared SwiftData store inside the App Group container.
nonisolated struct SharedStoreLocation: Equatable, Sendable {
    let directory: URL

    var storeURL: URL { directory.appendingPathComponent("TenThousandHours.store") }
    var lockFileURL: URL { directory.appendingPathComponent("TenThousandHours.lock") }
    /// Written only after the legacy store has been copied and the copy verified.
    /// The widget does not work with the store until this marker exists.
    var migrationMarkerURL: URL { directory.appendingPathComponent("LegacyStoreMigration.done") }

    init(directory: URL) {
        self.directory = directory
    }

    static func appGroup(
        identifier: String = AppGroup.identifier,
        fileManager: FileManager = .default
    ) throws -> SharedStoreLocation {
        guard let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            throw SharedStoreError.appGroupUnavailable
        }
        let directory = container
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return SharedStoreLocation(directory: directory)
    }

    func isMigrationComplete(fileManager: FileManager = .default) -> Bool {
        fileManager.fileExists(atPath: migrationMarkerURL.path)
    }
}

/// Location of the store used before stage 6.
///
/// Up to stage 6 the app created the container with the default `ModelConfiguration`. With no App
/// Group entitlement, SwiftData put it at `Application Support/default.store` in the app sandbox.
/// The default configuration must no longer be used: once the entitlement appears, SwiftData would
/// silently create a new, empty store in the App Group, and the old data would no longer be visible.
nonisolated enum LegacyStoreLocation {
    static var storeURL: URL {
        URL.applicationSupportDirectory.appendingPathComponent("default.store")
    }
}

nonisolated enum SharedStoreError: LocalizedError, Equatable {
    case appGroupUnavailable
    case migrationPending
    case storeBusy
    case lockUnavailable(errno: Int32)
    case activeSessionConflict
    case migrationVerificationFailed

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            String(localized: "Общее хранилище для виджетов недоступно. Данные сохраняются только в приложении.")
        case .migrationPending:
            String(localized: "Откройте приложение, чтобы подготовить данные")
        case .storeBusy:
            String(localized: "Хранилище занято. Попробуйте ещё раз.")
        case .lockUnavailable:
            String(localized: "Не удалось получить доступ к общему хранилищу")
        case .activeSessionConflict, .migrationVerificationFailed:
            String(localized: "Не удалось перенести данные в общее хранилище. Данные сохранены на устройстве.")
        }
    }
}
