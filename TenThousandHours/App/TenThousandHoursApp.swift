import SwiftData
import SwiftUI

@main
struct TenThousandHoursApp: App {
    private let modelContainer: ModelContainer
    @State private var trackingStore: TrackingStore

    init() {
        let persistence: PersistenceBootstrap.Result
        do {
            persistence = try Self.preparePersistence()
        } catch {
            fatalError("Не удалось создать хранилище SwiftData: \(error)")
        }
        modelContainer = persistence.container
        let repository = SwiftDataSessionRepository(container: persistence.container)
        #if DEBUG
        do {
            try UITestingStore.seedIfRequested(repository: repository)
        } catch {
            fatalError("Не удалось подготовить данные UI-тестов: \(error)")
        }
        #endif
        let store = TrackingStore(
            repository: repository,
            coordinator: persistence.coordinator,
            onSessionsChanged: WidgetTimelineReloader.reload
        )
        store.restore()
        if let error = persistence.sharedStoreError {
            store.reportStorageNotice(error)
        }
        if persistence.isShared {
            // The widget may have shown "Откройте приложение" until the migration finished.
            WidgetTimelineReloader.reload()
        }
        _trackingStore = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(trackingStore)
        }
        .modelContainer(modelContainer)
    }

    private static func preparePersistence() throws -> PersistenceBootstrap.Result {
        #if DEBUG
        if let storeURL = try UITestingStore.storeURLIfRequested() {
            return PersistenceBootstrap.Result(
                container: try ModelContainerFactory.makeContainer(storeURL: storeURL),
                coordinator: InProcessOperationCoordinator(),
                isShared: false,
                sharedStoreError: nil
            )
        }
        #endif
        return try PersistenceBootstrap().prepare()
    }
}
