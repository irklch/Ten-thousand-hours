import Foundation
import SwiftData

enum ModelContainerFactory {
    static let models: [any PersistentModel.Type] = [Session.self]

    static func makeContainer(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isStoredInMemoryOnly)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    static func makeContainer(storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    private static var schema: Schema {
        Schema(models)
    }
}
