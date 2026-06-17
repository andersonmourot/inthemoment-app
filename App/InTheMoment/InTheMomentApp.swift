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
        }
    }
}
