import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            DiscoverView()
                .tabItem { Label("Discover", systemImage: "sparkles") }

            MyEventsView()
                .tabItem { Label("My Events", systemImage: "rectangle.stack.badge.plus") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}

#Preview {
    RootTabView().environmentObject(AppModel())
}
