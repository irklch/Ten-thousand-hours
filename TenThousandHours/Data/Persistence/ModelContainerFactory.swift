import SwiftData

enum ModelContainerFactory {
    static let models: [any PersistentModel.Type] = []

    static func makeContainer(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isStoredInMemoryOnly)
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
