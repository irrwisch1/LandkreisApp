import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var visits: VisitStore

    private struct StateProgress: Identifiable {
        let name: String, done: Int, total: Int
        var id: String { name }
    }

    private var states: [StateProgress] {
        Dictionary(grouping: model.counties, by: \.federalState)
            .map { name, ds in
                StateProgress(name: name,
                              done: ds.filter { visits.isDone($0.id) }.count,
                              total: ds.count)
            }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        let done = model.counties.filter { visits.isDone($0.id) }.count
        let checked = model.counties.filter { visits.status($0.id) == .checked }.count
        let orange = model.counties.filter { visits.status($0.id) == .visited }.count

        NavigationStack {
            List {
                Section {
                    ProgressRow(title: "Deutschland", done: done, total: model.counties.count)
                    if checked > 0 {
                        LabeledContent("Davon unterwegs abgehakt", value: "\(checked)")
                    }
                    LabeledContent("Betreten ohne Fund", value: "\(orange)")
                    LabeledContent("Cache-Funde in DE", value: "\(visits.finds.values.reduce(0, +))")
                }
                Section("Bundesländer") {
                    ForEach(states) { state in
                        NavigationLink {
                            StateCountiesView(state: state.name)
                        } label: {
                            ProgressRow(title: state.name, done: state.done, total: state.total)
                        }
                    }
                }
            }
            .navigationTitle("Fortschritt")
        }
    }
}

struct ProgressRow: View {
    let title: String, done: Int, total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(done) / \(total)").monospacedDigit().foregroundStyle(.secondary)
                if done == total && total > 0 { Text("🏆") }
            }
            ProgressView(value: Double(done), total: Double(max(total, 1)))
                .tint(.green)
        }
    }
}

struct StateCountiesView: View {
    let state: String

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var visits: VisitStore
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        let counties = model.counties.filter { $0.federalState == state }
        let open = counties.filter { !visits.isDone($0.id) }
        let done = counties.filter { visits.isDone($0.id) }
        let distances = Dictionary(uniqueKeysWithValues: location.neighbors.map { ($0.county.id, $0.distance) })

        List {
            if open.isEmpty {
                Section {
                    Label("Alle Kreise gefunden 🏆", systemImage: "checkmark.seal")
                }
            } else {
                Section("Fehlen noch (\(open.count))") {
                    ForEach(open) { row($0, distance: distances[$0.id]) }
                }
            }
            if !done.isEmpty {
                Section("Erledigt (\(done.count))") {
                    ForEach(done) { row($0, distance: nil) }
                }
            }
        }
        .navigationTitle(state)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ county: County, distance: Double?) -> some View {
        Button { router.showOnMap(county) } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(visits.status(county.id).color)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading) {
                    Text(county.name)
                    Text(county.kind).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if county.id == location.currentCounty?.id {
                    Text("Du bist hier").font(.caption).foregroundStyle(.secondary)
                } else if let distance {
                    Text(Format.km(distance)).monospacedDigit().foregroundStyle(.secondary)
                }
            }
        }
        .tint(.primary)
    }
}
