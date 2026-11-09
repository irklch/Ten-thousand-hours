import SwiftData
import SwiftUI

@main
struct TenThousandHoursApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainerFactory.makeContainer()
        } catch {
            fatalError("Не удалось создать хранилище SwiftData: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
