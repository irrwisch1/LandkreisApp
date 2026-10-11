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
                        ProgressRow(title: state.name, done: state.done, total: state.total)
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
