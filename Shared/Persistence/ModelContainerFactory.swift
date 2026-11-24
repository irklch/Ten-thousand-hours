import Foundation
import SwiftData

/// Единственное место, где задаются схема SwiftData и расположение хранилища.
///
/// В продакшене хранилище одно: `<App Group>/Library/Application Support/TenThousandHours.store`.
/// Приложение и Widget Extension открывают его по одному и тому же явному URL; переключения на другие хранилища нет.
/// Хранилище в памяти и хранилище по произвольному URL — только для тестов, Preview и UI-тестов.
nonisolated enum ModelContainerFactory {
    static let appGroupIdentifier = "group.com.irklch.TenThousandHours"

    static var schema: Schema {
        Schema([Session.self])
    }

    /// URL общего хранилища. Бросает `appGroupUnavailable`, если контейнер App Group недоступен.
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

    /// Файл блокировки для операций с хранилищем (см. `FileLockCoordinator`) лежит рядом с хранилищем.
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
