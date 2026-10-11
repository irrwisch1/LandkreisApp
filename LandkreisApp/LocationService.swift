import Foundation
import CoreLocation

struct Neighbor: Identifiable {
    let county: County
    let distance: CLLocationDistance
    let bearing: Double
    var id: String { county.id }
}

@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published private(set) var location: CLLocation?
    @Published private(set) var currentCounty: County?
    @Published private(set) var distanceToBorder: CLLocationDistance?
    @Published private(set) var neighbors: [Neighbor] = []
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined

    var model: AppModel?
    var onCountyEntered: ((County, _ notify: Bool) -> Void)?

    private let manager = CLLocationManager()
    private var lastComputation: CLLocation?

    private var lastKey: String? {
        get { UserDefaults.standard.string(forKey: "lastCounty") }
        set { UserDefaults.standard.set(newValue, forKey: "lastCounty") }
    }

    func start() {
        manager.delegate = self
        manager.activityType = .otherNavigation
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 150
        manager.pausesLocationUpdatesAutomatically = false
        authorization = manager.authorizationStatus
        if authorization == .notDetermined { manager.requestWhenInUseAuthorization() }
        applyMode()
    }

    func applyMode() {
        let powerSaving = UserDefaults.standard.bool(forKey: "powerSaving")
        manager.allowsBackgroundLocationUpdates = !powerSaving
        manager.showsBackgroundLocationIndicator = !powerSaving
        manager.startUpdatingLocation()
        manager.startMonitoringSignificantLocationChanges()
    }

    func recheckCounty() {
        guard let location else { return }
        checkCountyChange(location)
        computeDistances(location.coordinate)
    }

    private func process(_ loc: CLLocation) {
        guard loc.horizontalAccuracy >= 0, loc.horizontalAccuracy <= 1000 else { return }
        location = loc
        checkCountyChange(loc)

        if let l = lastComputation, l.distance(from: loc) < 100, !neighbors.isEmpty { return }
        lastComputation = loc
        computeDistances(loc.coordinate)
    }

    private func checkCountyChange(_ loc: CLLocation) {
        guard let model, model.bordersReady else { return }
        let c = loc.coordinate
        if let cur = currentCounty, model.contains(cur, c) { return }

        let candidate = model.county(at: c)
        if let d = candidate, currentCounty != nil,
           model.distanceToBorder(of: d, from: c) < max(loc.horizontalAccuracy, 50) {
            return
        }

        currentCounty = candidate
        let key = candidate?.id ?? "abroad"
        guard key != lastKey else { return }
        let notify = lastKey != nil
        lastKey = key
        if let d = candidate { onCountyEntered?(d, notify) }
    }

    private func computeDistances(_ c: CLLocationCoordinate2D) {
        let counties = model?.counties ?? []
        var list: [Neighbor] = []
        list.reserveCapacity(counties.count)
        for d in counties where d.id != currentCounty?.id {
            let b = d.nearestBorderPoint(to: c)
            list.append(Neighbor(county: d, distance: b.distance, bearing: Geo.bearing(from: c, to: b.point)))
        }
        neighbors = list.sorted { $0.distance < $1.distance }
        distanceToBorder = currentCounty.flatMap { cur in model?.distanceToBorder(of: cur, from: c) }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if status == .authorizedWhenInUse { self.manager.requestAlwaysAuthorization() }
            self.applyMode()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in self.process(loc) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
