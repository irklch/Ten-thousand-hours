import SwiftData
import SwiftUI

@main
struct TenThousandHoursApp: App {
    private let modelContainer: ModelContainer
    @State private var trackingStore: TrackingStore

    init() {
        let container: ModelContainer
        do {
            container = try Self.makeModelContainer()
        } catch {
            fatalError("Не удалось создать хранилище SwiftData: \(error)")
        }
        modelContainer = container
        let repository = SwiftDataSessionRepository(context: container.mainContext)
        #if DEBUG
        do {
            try UITestingStore.seedIfRequested(repository: repository)
        } catch {
            fatalError("Не удалось подготовить данные UI-тестов: \(error)")
        }
        #endif
        let store = TrackingStore(repository: repository)
        store.restore()
        _trackingStore = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(trackingStore)
        }
        .modelContainer(modelContainer)
    }

    private static func makeModelContainer() throws -> ModelContainer {
        #if DEBUG
        if let storeURL = try UITestingStore.storeURLIfRequested() {
            return try ModelContainerFactory.makeContainer(storeURL: storeURL)
        }
        #endif
        return try ModelContainerFactory.makeContainer()
    }
}
