#if DEBUG
import SwiftData

extension TrackingStore {
    static func preview() -> TrackingStore {
        do {
            let container = try ModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
            return TrackingStore(repository: SwiftDataSessionRepository(context: container.mainContext))
        } catch {
            fatalError("Не удалось создать хранилище для Preview: \(error)")
        }
    }
}
#endif
