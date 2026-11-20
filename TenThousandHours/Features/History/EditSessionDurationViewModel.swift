import Foundation
import Observation

@Observable
final class EditSessionDurationViewModel {
    var input: SessionDurationInput
    private(set) var isSaving = false
    private(set) var saveError: (any Error)?

    let session: SessionSnapshot
    @ObservationIgnored private let store: TrackingStore

    init(session: SessionSnapshot, store: TrackingStore) {
        self.session = session
        self.store = store
        self.input = SessionDurationInput(durationSeconds: session.durationSeconds ?? 0)
    }

    nonisolated deinit {}

    var currentDurationText: String {
        SessionDurationFormatter.format(session.durationSeconds ?? 0)
    }

    var validationMessage: String? {
        if case .failure(let error) = input.result {
            return error.message
        }
        return nil
    }

    var canSave: Bool {
        input.durationSeconds != nil && !isSaving
    }

    var saveErrorMessage: String? {
        guard let saveError else { return nil }
        if let sessionError = saveError as? SessionError {
            return sessionError.errorDescription
        }
        return String(localized: "Не удалось сохранить данные. Попробуйте ещё раз.")
    }

    func save() -> Bool {
        guard !isSaving, let seconds = input.durationSeconds else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            try store.updateDuration(ofSessionWithID: session.id, to: seconds)
            saveError = nil
            return true
        } catch {
            saveError = error
            return false
        }
    }

    func dismissSaveError() {
        saveError = nil
    }
}
