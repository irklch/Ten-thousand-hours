import SwiftUI

@main
struct TenThousandHoursApp: App {
    @State private var trackingStore: TrackingStore?
    @State private var storageError: (any Error)?

    init() {
        do {
            _trackingStore = State(initialValue: try Self.openStore())
        } catch {
            _storageError = State(initialValue: error)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let trackingStore {
                RootView()
                    .environment(trackingStore)
            } else {
                StorageUnavailableView(error: storageError, retry: retry)
            }
        }
    }

    /// Opens the store again after a temporary unavailability. Creates no replacement store.
    private func retry() {
        do {
            trackingStore = try Self.openStore()
            storageError = nil
        } catch {
            storageError = error
        }
    }

    private static func openStore() throws -> TrackingStore {
        #if DEBUG
        try UITestingStore.simulateFailureIfRequested()
        if let storeURL = try UITestingStore.storeURLIfRequested() {
            return try TrackingStore.open(storeURL: storeURL, seed: { try UITestingStore.seedIfRequested(repository: $0) })
        }
        #endif
        return try TrackingStore.open(storeURL: ModelContainerFactory.sharedStoreURL())
    }
}

extension TrackingStore {
    /// The app's store over the store file in the App Group (in UI tests, a temporary file).
    /// If the store cannot be opened or read, it throws: there is no fallback store and no made-up zero state.
    static func open(
        storeURL: URL,
        seed: (any SessionRepository) throws -> Void = { _ in }
    ) throws -> TrackingStore {
        let repository = SwiftDataSessionRepository(container: try ModelContainerFactory.makeContainer(storeURL: storeURL))
        try seed(repository)
        let store = TrackingStore(
            repository: repository,
            lock: FileLockCoordinator(lockFileURL: ModelContainerFactory.lockFileURL(forStoreAt: storeURL)),
            onSessionsChanged: WidgetTimelineReloader.reload
        )
        store.restore()
        if let error = store.error {
            throw error
        }
        return store
    }
}
