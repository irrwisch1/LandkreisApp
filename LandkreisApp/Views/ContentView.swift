import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var router = AppRouter()

    var body: some View {
        if let error = model.loadError {
            ContentUnavailableView("Kreisdaten fehlen", systemImage: "map",
                                   description: Text(error))
        } else {
            TabView(selection: $router.tab) {
                CountyMapView()
                    .tabItem { Label("Karte", systemImage: "map") }
                    .tag(AppRouter.Tab.map)
                NearbyView()
                    .tabItem { Label("In der Nähe", systemImage: "location.north.line") }
                    .tag(AppRouter.Tab.nearby)
                StatsView()
                    .tabItem { Label("Fortschritt", systemImage: "chart.bar") }
                    .tag(AppRouter.Tab.stats)
                SettingsView()
                    .tabItem { Label("Einstellungen", systemImage: "gearshape") }
                    .tag(AppRouter.Tab.settings)
            }
            .environmentObject(router)
        }
    }
}
