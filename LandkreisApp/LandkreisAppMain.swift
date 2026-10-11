import SwiftUI

@main
struct LandkreisAppMain: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let env = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(env.model)
                .environmentObject(env.visits)
                .environmentObject(env.location)
        }
    }
}
