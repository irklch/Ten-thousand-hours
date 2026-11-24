import SwiftUI
import UserNotifications

@main
struct TenThousandHoursApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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

    /// Заново открывает хранилище после временной недоступности. Не создаёт хранилище на замену.
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
            return try TrackingStore.open(
                storeURL: storeURL,
                preferences: .ephemeral(),
                requestsNotificationPermission: false,
                seed: { try UITestingStore.seedIfRequested(repository: $0) }
            )
        }
        #endif
        return try TrackingStore.open(storeURL: ModelContainerFactory.sharedStoreURL())
    }
}

extension TrackingStore {
    /// Store приложения поверх файла хранилища в App Group (в UI-тестах — временный файл).
    /// Если хранилище не открывается или не читается, бросает ошибку: запасного хранилища и выдуманного нулевого состояния нет.
    static func open(
        storeURL: URL,
        preferences: SharedPreferences = .shared,
        requestsNotificationPermission: Bool = true,
        seed: (any SessionRepository) throws -> Void = { _ in }
    ) throws -> TrackingStore {
        let repository = SwiftDataSessionRepository(container: try ModelContainerFactory.makeContainer(storeURL: storeURL))
        try seed(repository)
        let store = TrackingStore(
            repository: repository,
            lock: FileLockCoordinator(lockFileURL: ModelContainerFactory.lockFileURL(forStoreAt: storeURL)),
            preferences: preferences,
            onSessionsChanged: WidgetTimelineReloader.reload,
            onStateRead: { state in
                Task {
                    // Разрешение на напоминания спрашиваем, когда таймер идёт: в этот момент понятно, зачем они нужны.
                    // Системный запрос показывается один раз; затем напоминания планируются с учётом ответа.
                    if requestsNotificationPermission, state.activeSession != nil {
                        await DailyReminderScheduler.requestAuthorizationIfNeeded()
                    }
                    await SharedTracking.syncSystemState(state)
                }
            }
        )
        store.restore()
        if let error = store.error {
            throw error
        }
        return store
    }
}

/// Делегат нужен только для нажатия на напоминание: его надо получить до первого кадра, поэтому он
/// назначается при запуске приложения.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            NotificationCenter.default.post(name: .dailyReminderOpened, object: nil)
        }
    }
}

extension Notification.Name {
    static let dailyReminderOpened = Notification.Name("TenThousandHours.dailyReminderOpened")
}
