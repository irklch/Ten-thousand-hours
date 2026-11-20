import SwiftUI

struct EditSessionDurationView: View {
    @State var viewModel: EditSessionDurationViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Сейчас") {
                        Text(verbatim: viewModel.currentDurationText)
                    }
                    .accessibilityIdentifier("edit.current")
                }

                Section {
                    durationField("Часы", text: $viewModel.input.hours, identifier: "edit.hours")
                    durationField("Минуты", text: $viewModel.input.minutes, identifier: "edit.minutes")
                } header: {
                    Text("Новая продолжительность")
                } footer: {
                    if let message = viewModel.validationMessage {
                        Text(verbatim: message)
                            .accessibilityIdentifier("edit.validation")
                    }
                }
            }
            .navigationTitle("Длительность")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        if viewModel.save() {
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .alert(
                "Ошибка",
                isPresented: Binding(
                    get: { viewModel.saveErrorMessage != nil },
                    set: { isPresented in
                        if !isPresented { viewModel.dismissSaveError() }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(verbatim: viewModel.saveErrorMessage ?? "")
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(viewModel.isSaving)
    }

    private func durationField(_ title: LocalizedStringKey, text: Binding<String>, identifier: String) -> some View {
        LabeledContent(title) {
            TextField(title, text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .accessibilityLabel(Text(title))
                .accessibilityIdentifier(identifier)
        }
    }
}
