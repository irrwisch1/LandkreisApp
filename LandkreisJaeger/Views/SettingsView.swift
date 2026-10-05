import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var visits: VisitStore
    @EnvironmentObject private var location: LocationService

    @AppStorage("powerSaving") private var powerSaving = false
    @StateObject private var findsImport = FindsImport()
    @State private var importPresented = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("„My Finds“ importieren (ZIP oder GPX)") { importPresented = true }
                    Link(destination: URL(string: "https://www.geocaching.com/pocket/")!) {
                        Label("Pocket Queries auf geocaching.com", systemImage: "safari")
                    }
                    if let d = visits.lastImport {
                        LabeledContent("Letzter Import", value: d.formatted(date: .abbreviated, time: .shortened))
                    }
                } header: {
                    Text("Geocaching")
                } footer: {
                    Text("geocaching.com → Pocket Queries → „Add to Queue“ bei „My Finds“ (Premium). ZIP herunterladen und hier direkt wählen, Entpacken ist nicht nötig.")
                }

                Section {
                    Toggle("Energiesparmodus", isOn: $powerSaving)
                    if location.authorization != .authorizedAlways {
                        Button("Standort „Immer“ erlauben") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                } header: {
                    Text("Alarm")
                } footer: {
                    Text("Sparmodus: Im Hintergrund nur „signifikante Ortswechsel“. Spart Akku, die Meldung kommt aber teils erst einige Kilometer hinter der Grenze.")
                }

                Section {
                    Button("Alle Daten zurücksetzen", role: .destructive) { visits.reset() }
                }

                Section {
                    Text("Verwaltungsgrenzen: © [BKG](https://www.bkg.bund.de) (2026) [dl-de/by-2-0](https://www.govdata.de/dl-de/by-2-0), [Datenquellen](https://sgx.geodatenzentrum.de/web_public/gdz/datenquellen/datenquellen_vg_nuts.pdf). Daten verändert: Landflächen gefiltert, nach WGS84 umgerechnet, Grenzen vereinfacht.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .disabled(findsImport.isRunning)
            .overlay {
                if findsImport.isRunning { ImportProgressOverlay(findsImport: findsImport) }
            }
            .navigationTitle("Einstellungen")
            .onChange(of: powerSaving) { location.applyMode() }
            .fileImporter(isPresented: $importPresented,
                          allowedContentTypes: [.zip, UTType(filenameExtension: "gpx") ?? .xml, .xml]) { result in
                guard case .success(let url) = result else { return }
                Task {
                    let r = await findsImport.run(url: url, counties: model.counties, visits: visits)
                    message = "\(r.total) Funde gelesen, davon \(r.matched) in Deutschland.\n\(visits.finds.count) Kreise sind jetzt grün."
                }
            }
            .alert("Import abgeschlossen",
                   isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") {}
            } message: {
                Text(message ?? "")
            }
        }
    }
}

struct ImportProgressOverlay: View {
    @ObservedObject var findsImport: FindsImport

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                Text("Import läuft").font(.headline)
                ProgressView(value: findsImport.progress) {
                    Text(findsImport.phase).font(.subheadline)
                } currentValueLabel: {
                    Text(findsImport.progress, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                }
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 32)
        }
    }
}
