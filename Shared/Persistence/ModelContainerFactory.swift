import Foundation
import SwiftData

/// The single place that defines the SwiftData schema and the store location.
///
/// In production there is one store: `<App Group>/Library/Application Support/TenThousandHours.store`.
/// The app and the Widget Extension open it at the same explicit URL; there is no switching to other stores.
/// An in-memory store and a store at an arbitrary URL are only for tests, Preview and UI tests.
nonisolated enum ModelContainerFactory {
    static let appGroupIdentifier = "group.com.irklch.TenThousandHours"

    static var schema: Schema {
        Schema([Session.self])
    }

    /// URL of the shared store. Throws `appGroupUnavailable` if the App Group container is unavailable.
    static func sharedStoreURL(
        appGroupIdentifier: String = appGroupIdentifier,
        fileManager: FileManager = .default
    ) throws -> URL {
        guard let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw SharedStoreError.appGroupUnavailable
        }
        return container
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent("TenThousandHours.store")
    }

    /// The lock file for operations on the store (see `FileLockCoordinator`) lives next to the store.
    static func lockFileURL(forStoreAt storeURL: URL) -> URL {
        storeURL.deletingPathExtension().appendingPathExtension("lock")
    }

    static func makeContainer(storeURL: URL) throws -> ModelContainer {
        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: storeURL))
    }

    static func makeContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: isStoredInMemoryOnly)
        )
    }
}

nonisolated enum SharedStoreError: LocalizedError, Equatable {
    case appGroupUnavailable
    case storeBusy
    case lockUnavailable

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            String(localized: "Общее хранилище недоступно")
        case .storeBusy:
            String(localized: "Хранилище занято. Попробуйте ещё раз.")
        case .lockUnavailable:
            String(localized: "Не удалось получить доступ к общему хранилищу")
        }
    }
}
