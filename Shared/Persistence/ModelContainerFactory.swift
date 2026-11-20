import Foundation
import SwiftData

enum ModelContainerFactory {
    static let models: [any PersistentModel.Type] = [Session.self]

    static func makeContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isStoredInMemoryOnly)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// The location is always explicit (see `LegacyStoreLocation`), so SwiftData never picks a store on its own.
    static func makeContainer(storeURL: URL) throws -> ModelContainer {
        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    private static var schema: Schema {
        Schema(models)
    }
}
