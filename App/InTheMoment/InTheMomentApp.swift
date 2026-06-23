import SwiftUI

@main
struct InTheMomentApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(model)
                .environmentObject(auth)
                .task {
                    let account = await auth.restore()
                    await model.bootstrap(account: account)
                }
                .tint(Color.appAccent)
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
