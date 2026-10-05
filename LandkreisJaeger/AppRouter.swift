import SwiftUI

@MainActor
final class AppRouter: ObservableObject {
    enum Tab: Hashable { case map, nearby, stats, settings }

    struct CountyRequest: Equatable {
        let id = UUID()
        let countyID: String
    }

    @Published var tab: Tab = .map
    @Published var countyRequest: CountyRequest?

    func showOnMap(_ county: County) {
        countyRequest = CountyRequest(countyID: county.id)
        tab = .map
    }
}
