import SwiftData

/// An in-memory store for `#Preview`. `#Preview` blocks are compiled in Release too, so this is not under `#if DEBUG`.
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
