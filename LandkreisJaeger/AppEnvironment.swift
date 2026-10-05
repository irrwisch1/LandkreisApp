import SwiftUI
import CoreLocation
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var counties: [County] = []
    @Published private(set) var loadError: String?

    func load() {
        do { counties = try CountyLoader.load() }
        catch { loadError = error.localizedDescription }
    }

    func county(at c: CLLocationCoordinate2D) -> County? {
        counties.first { $0.contains(c) }
    }
}

@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let model = AppModel()
    let visits = VisitStore()
    let location = LocationService()

    private init() {
        model.load()
        location.counties = model.counties
        location.onCountyEntered = { [unowned self] county, notify in
            self.countyEntered(county, notify: notify)
        }
        location.start()
    }

    private func countyEntered(_ county: County, notify: Bool) {
        let firstTime = visits.markVisited(county.id)
        guard notify, !visits.isDone(county.id) else { return }

        let text = firstTime
            ? "🆕 Zum ersten Mal hier! Noch kein Fund, Zeit für einen Cache."
            : "🔴 Hier fehlt dir noch ein Fund."
        Notifier.send(title: "\(county.displayName) betreten", body: text)
    }
}

enum Notifier {
    static func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Notifier.requestAuthorization()
        _ = AppEnvironment.shared
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
