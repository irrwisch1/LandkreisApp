import ActivityKit
import Combine
import UIKit

@MainActor
final class LiveActivityController {
    static let settingKey = "liveActivity"
    static var isEnabled: Bool { UserDefaults.standard.object(forKey: settingKey) as? Bool ?? true }

    private let location: LocationService
    private let visits: VisitStore
    private var activity: Activity<CountyActivityAttributes>?
    private var lastState: CountyActivityAttributes.ContentState?
    private var cancellables: Set<AnyCancellable> = []

    init(location: LocationService, visits: VisitStore) {
        self.location = location
        self.visits = visits

        let running = Activity<CountyActivityAttributes>.activities
        if let first = running.first {
            activity = first
            observe(first)
        }
        for extra in running.dropFirst() {
            Task { await extra.end(nil, dismissalPolicy: .immediate) }
        }

        location.objectWillChange
            .merge(with: visits.objectWillChange)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.update() }
            .store(in: &cancellables)

        // Live Activities can only be started while the app is in the foreground
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.applySetting() }
            .store(in: &cancellables)
    }

    func applySetting() {
        if Self.isEnabled { start() } else { stop() }
    }

    private func start() {
        guard activity == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = makeState()
        do {
            let a = try Activity.request(attributes: CountyActivityAttributes(),
                                         content: .init(state: state, staleDate: nil))
            activity = a
            lastState = state
            observe(a)
        } catch {
            print("Live Activity not started: \(error)")
        }
    }

    private func stop() {
        guard let a = activity else { return }
        activity = nil
        lastState = nil
        Task { await a.end(nil, dismissalPolicy: .immediate) }
    }

    private func update() {
        guard let activity else { return }
        let state = makeState()
        guard state != lastState else { return }
        lastState = state
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    private func observe(_ a: Activity<CountyActivityAttributes>) {
        Task { [weak self] in
            for await s in a.activityStateUpdates where s == .ended || s == .dismissed {
                guard let self, self.activity?.id == a.id else { return }
                self.activity = nil
                self.lastState = nil
                return
            }
        }
    }

    private func makeState() -> CountyActivityAttributes.ContentState {
        let county = location.currentCounty
        let nextOpen = location.neighbors.first { !visits.isDone($0.county.id) }
        return .init(countyName: county?.displayName,
                     status: county.map { visits.status($0.id) } ?? .open,
                     nextOpenName: nextOpen?.county.displayName,
                     nextOpenDistance: nextOpen.map { Self.displayRounded($0.distance) })
    }

    /// Coarse enough that the activity is not updated on every location fix
    private static func displayRounded(_ meters: Double) -> Double {
        let step: Double = meters < 1000 ? 50 : meters < 10_000 ? 100 : 1000
        return (meters / step).rounded() * step
    }
}
