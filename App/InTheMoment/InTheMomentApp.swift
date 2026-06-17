import SwiftUI

@main
struct InTheMomentApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(model)
                .task { await model.bootstrap() }
                .tint(.appAccent)
                .onOpenURL { url in
                    Task { await model.handle(url: url) }
                }
                .sheet(item: $model.deepLinkedEvent) { event in
                    NavigationStack {
                        EventDetailView(event: event)
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button("Done") { model.deepLinkedEvent = nil }
                                }
                            }
                    }
                }
        }
    }
}
