import SwiftUI

@main
struct LandkreisJaegerApp: App {
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
