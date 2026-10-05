import SwiftUI
import MapKit

struct CountyMapView: View {
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: AppRouter
    @State private var selection: County?
    @State private var focus: MapFocus?
    @State private var searchPresented = false
    @State private var searchResult: County?

    var body: some View {
        CountyMap(currentID: location.currentCounty?.id, focus: focus, selection: $selection)
            .equatable()
            .safeAreaInset(edge: .top) { CurrentCountyBanner { searchPresented = true } }
            .sheet(item: $selection) { county in
                CountyDetailView(county: county)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $searchPresented, onDismiss: showSearchResult) {
                CountySearchView { county in
                    searchResult = county
                    searchPresented = false
                }
            }
            .onAppear(perform: handleRequest)
            .onChange(of: router.countyRequest) { handleRequest() }
    }

    private func showSearchResult() {
        guard let county = searchResult else { return }
        searchResult = nil
        show(county)
    }

    private func handleRequest() {
        guard let request = router.countyRequest else { return }
        router.countyRequest = nil
        if let county = model.counties.first(where: { $0.id == request.countyID }) {
            show(county)
        }
    }

    private func show(_ county: County) {
        searchPresented = false
        focus = MapFocus(showingInUpperHalf: county.boundingRect)
        selection = county
    }
}

struct MapFocus: Equatable {
    let id = UUID()
    let rect: MKMapRect

    init(showingInUpperHalf r: MKMapRect) {
        let padX = r.width * 0.15, padY = r.height * 0.15
        rect = MKMapRect(x: r.minX - padX, y: r.minY - padY,
                         width: r.width + 2 * padX, height: (r.height + 2 * padY) * 2)
    }

    static func == (a: MapFocus, b: MapFocus) -> Bool { a.id == b.id }
}

struct CountyMap: View, Equatable {
    let currentID: String?
    let focus: MapFocus?
    @Binding var selection: County?

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var visits: VisitStore
    @State private var position: MapCameraPosition = .userLocation(fallback: .region(.germany))

    nonisolated static func == (a: CountyMap, b: CountyMap) -> Bool {
        a.currentID == b.currentID && a.focus?.id == b.focus?.id
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                ForEach(model.counties) { county in
                    let color = visits.status(county.id).color
                    let isCurrent = county.id == currentID
                    ForEach(county.polygons.indices, id: \.self) { i in
                        MapPolygon(county.polygons[i])
                            .foregroundStyle(color.opacity(isCurrent ? 0.5 : 0.28))
                            .stroke(isCurrent ? Color.blue : color, lineWidth: isCurrent ? 3 : 0.7)
                    }
                }
                UserAnnotation()
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onTapGesture { point in
                if let c = proxy.convert(point, from: .local) {
                    selection = model.county(at: c)
                }
            }
            .onChange(of: focus?.id) {
                guard let focus else { return }
                withAnimation { position = .rect(focus.rect) }
            }
        }
    }
}

struct CurrentCountyBanner: View {
    let onSearch: () -> Void
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var visits: VisitStore

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(location.currentCounty.map { visits.status($0.id).color } ?? .gray)
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(location.currentCounty?.displayName ?? "Standort wird ermittelt …")
                    .font(.headline)
                if let d = location.distanceToBorder {
                    Text("Kreisgrenze in \(Format.km(d))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Kreis suchen")
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}

struct CountyDetailView: View {
    let county: County
    @EnvironmentObject private var visits: VisitStore
    @EnvironmentObject private var location: LocationService

    var body: some View {
        let status = visits.status(county.id)
        VStack(alignment: .leading, spacing: 12) {
            Text(county.displayName).font(.title2.bold())
            Text(county.federalState).foregroundStyle(.secondary)
            Label(status.text, systemImage: "circle.fill").foregroundStyle(status.color)

            if let n = visits.finds[county.id], n > 0 {
                Label("\(n) Cache-Fund\(n == 1 ? "" : "e")", systemImage: "shippingbox")
            }
            if let date = visits.firstFinds[county.id] {
                Label("Erster Fund: \(date.formatted(date: .abbreviated, time: .omitted))",
                      systemImage: "checkmark.seal")
            }
            if let date = visits.checked[county.id] {
                Label("Abgehakt: \(date.formatted(date: .abbreviated, time: .omitted))",
                      systemImage: "checkmark.circle")
            }
            if let date = visits.firstVisit(county.id) {
                Label("Erstmals betreten: \(date.formatted(date: .abbreviated, time: .omitted))",
                      systemImage: "figure.walk")
            }
            if let loc = location.location, !county.contains(loc.coordinate) {
                let b = county.nearestBorderPoint(to: loc.coordinate)
                Label("Grenze in \(Format.km(b.distance))", systemImage: "ruler")
                Button {
                    navigate(to: b.point)
                } label: {
                    Label("Zur Kreisgrenze navigieren", systemImage: "car.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            CheckButton(countyID: county.id)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func navigate(to point: CLLocationCoordinate2D) {
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: point))
        destination.name = "Grenze \(county.displayName)"
        destination.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

struct CheckButton: View {
    let countyID: String
    @EnvironmentObject private var visits: VisitStore

    var body: some View {
        let status = visits.status(countyID)
        if status != .found {
            let isChecked = status == .checked
            Button {
                visits.setChecked(countyID, !isChecked)
            } label: {
                Label(isChecked ? "Haken entfernen" : "Als gefunden abhaken",
                      systemImage: isChecked ? "xmark.circle" : "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(isChecked ? .secondary : .teal)
        }
    }
}
