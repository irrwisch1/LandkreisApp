import SwiftUI

struct CountySearchView: View {
    let onSelect: (County) -> Void

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var visits: VisitStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var searchActive = true

    private var results: [County] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return model.counties }
        let matches = model.counties.filter {
            $0.displayName.localizedStandardContains(q) || $0.federalState.localizedStandardContains(q)
        }
        let prefix = matches.filter {
            $0.name.range(of: q, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
        }
        let prefixIDs = Set(prefix.map(\.id))
        return prefix + matches.filter { !prefixIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List(results) { county in
                Button { onSelect(county) } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(visits.status(county.id).color)
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading) {
                            Text(county.name)
                            Text("\(county.kind) · \(county.federalState)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.primary)
            }
            .listStyle(.plain)
            .navigationTitle("Kreis suchen")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, isPresented: $searchActive,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Name oder Bundesland")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .overlay {
                if results.isEmpty { ContentUnavailableView.search(text: query) }
            }
        }
    }
}
