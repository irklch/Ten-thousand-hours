import Foundation
import Observation

struct HistoryItem: Identifiable, Equatable {
    let session: SessionSnapshot

    var id: UUID { session.id }
    var durationText: String { SessionDurationFormatter.format(durationSeconds) }
    var dateText: String { SessionDateFormatter.format(session.startDate) }
    var accessibilityLabel: String {
        "\(SessionDurationFormatter.spoken(durationSeconds)), \(dateText)"
    }

    var durationSeconds: Int { session.durationSeconds ?? 0 }
}

@Observable
final class HistoryViewModel {
    private(set) var items: [HistoryItem] = []
    private(set) var loadError: (any Error)?
    var editedSession: SessionSnapshot?

    @ObservationIgnored let store: TrackingStore

    init(store: TrackingStore) {
        self.store = store
    }

    nonisolated deinit {}

    var isEmpty: Bool { items.isEmpty }

    func reload() {
        do {
            items = try store.completedSessions()
                .filter { !$0.isActive }
                .map(HistoryItem.init)
            loadError = nil
        } catch {
            loadError = error
        }
    }

    func edit(_ item: HistoryItem) {
        editedSession = item.session
    }

    func makeEditViewModel(for session: SessionSnapshot) -> EditSessionDurationViewModel {
        EditSessionDurationViewModel(session: session, store: store)
    }
}
