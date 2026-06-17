import SwiftUI
import InTheMomentCore

/// Form for a creator to start a new event page.
struct CreateEventView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var details = ""
    @State private var location = ""
    @State private var date = Date()

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
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await model.createEvent(
                                title: title,
                                details: details,
                                location: location,
                                date: date
                            )
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

#Preview {
    CreateEventView().environmentObject(AppModel())
}
