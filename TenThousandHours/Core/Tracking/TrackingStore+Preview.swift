import SwiftData

/// Store в памяти для `#Preview`. Блоки `#Preview` компилируются и в Release, поэтому это не под `#if DEBUG`.
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
