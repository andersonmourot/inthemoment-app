import SwiftUI
import InTheMomentCore

/// Form for editing an existing event's details and publish state.
struct EditEventView: View {
    let event: Event
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var details: String
    @State private var location: String
    @State private var date: Date
    @State private var isPublished: Bool

    init(event: Event) {
        self.event = event
        _title = State(initialValue: event.title)
        _details = State(initialValue: event.details ?? "")
        _location = State(initialValue: event.location ?? "")
        _date = State(initialValue: event.date)
        _isPublished = State(initialValue: event.isPublished)
    }

    private var canSave: Bool { Event.isValidTitle(title) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    TextField("Title", text: $title)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Location", text: $location)
                }
                Section("About") {
                    TextField("Description", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Toggle("Published", isOn: $isPublished)
                } footer: {
                    Text("Drafts are hidden from the public Discover feed.")
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            var updated = event
                            updated.title = title
                            updated.details = details.trimmedNonEmpty
                            updated.location = location.trimmedNonEmpty
                            updated.date = date
                            updated.isPublished = isPublished
                            await model.updateEvent(updated)
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
