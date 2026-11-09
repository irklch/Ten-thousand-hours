import SwiftData
import SwiftUI

@main
struct TenThousandHoursApp: App {
    private let modelContainer: ModelContainer
    @State private var trackingStore: TrackingStore

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainerFactory.makeContainer()
        } catch {
            fatalError("Не удалось создать хранилище SwiftData: \(error)")
        }
        modelContainer = container
        _trackingStore = State(
            initialValue: TrackingStore(repository: SwiftDataSessionRepository(context: container.mainContext))
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(trackingStore)
        }
        .modelContainer(modelContainer)
    }
}
