import SwiftUI

struct NearbyView: View {
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var visits: VisitStore
    @EnvironmentObject private var router: AppRouter

    private var nearestOpen: [Neighbor] {
        Array(location.neighbors.lazy.filter { !visits.isDone($0.county.id) }.prefix(5))
    }

    var body: some View {
        NavigationStack {
            List {
                if let current = location.currentCounty {
                    Section("Du bist hier") {
                        Button { router.showOnMap(current) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(current.displayName).font(.headline)
                                Text(visits.status(current.id).text)
                                    .foregroundStyle(visits.status(current.id).color)
                                if let d = location.distanceToBorder {
                                    Text("Nächste Grenze: \(Format.km(d))").foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(.primary)
                        CheckButton(countyID: current.id)
                    }
                }
                if !nearestOpen.isEmpty {
                    Section("Nächste offene Kreise 🎯") {
                        ForEach(nearestOpen) { neighborButton($0) }
                    }
                }
                Section("Nächstgelegene Kreise") {
                    ForEach(location.neighbors.prefix(15)) { neighborButton($0) }
                }
            }
            .navigationTitle("In der Nähe")
            .overlay {
                if location.location == nil {
                    ContentUnavailableView("Kein Standort", systemImage: "location.slash",
                                           description: Text("Bitte Ortungsdienste für LandkreisJäger erlauben."))
                }
            }
        }
    }

    private func neighborButton(_ neighbor: Neighbor) -> some View {
        Button { router.showOnMap(neighbor.county) } label: {
            NeighborRow(neighbor: neighbor)
        }
        .tint(.primary)
    }
}

struct NeighborRow: View {
    let neighbor: Neighbor
    @EnvironmentObject private var visits: VisitStore

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(visits.status(neighbor.county.id).color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading) {
                Text(neighbor.county.name)
                Text(neighbor.county.kind).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(Format.km(neighbor.distance)).monospacedDigit()
                HStack(spacing: 3) {
                    Image(systemName: "location.north.fill")
                        .rotationEffect(.degrees(neighbor.bearing))
                    Text(Geo.compassDirection(neighbor.bearing))
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
