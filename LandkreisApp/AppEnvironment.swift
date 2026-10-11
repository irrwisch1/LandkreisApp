import SwiftUI
import CoreLocation
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var counties: [County] = []
    @Published private(set) var loadError: String?
    /// Exact borders, loaded in the background. If loading fails, the simplified map borders are used.
    private(set) var borders: CountyBorders?
    /// Set once loading the exact borders has finished, even if it failed
    private(set) var bordersReady = false
    var onBordersLoaded: (() -> Void)?
    private var byID: [String: County] = [:]

    func load() {
        do {
            counties = try CountyLoader.load()
            byID = Dictionary(uniqueKeysWithValues: counties.map { ($0.id, $0) })
        } catch {
            loadError = error.localizedDescription
        }
        Task {
            borders = await Task.detached(priority: .utility) { try? CountyBorders.load() }.value
            bordersReady = true
            onBordersLoaded?()
        }
    }

    func county(at c: CLLocationCoordinate2D) -> County? {
        guard let borders else { return counties.first { $0.contains(c) } }
        return borders.county(at: c).flatMap { byID[$0] }
    }

    func contains(_ county: County, _ c: CLLocationCoordinate2D) -> Bool {
        borders?.contains(county.id, c) ?? county.contains(c)
    }

    func distanceToBorder(of county: County, from c: CLLocationCoordinate2D) -> CLLocationDistance {
        borders?.distanceToBorder(of: county.id, from: c) ?? county.nearestBorderPoint(to: c).distance
    }
}

@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let model = AppModel()
    let visits = VisitStore()
    let location = LocationService()
    private(set) lazy var liveActivity = LiveActivityController(location: location, visits: visits)

    private init() {
        model.load()
        location.model = model
        model.onBordersLoaded = { [unowned self] in self.location.recheckCounty() }
        location.onCountyEntered = { [unowned self] county, notify in
            self.countyEntered(county, notify: notify)
        }
        location.start()
        liveActivity.applySetting()
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
