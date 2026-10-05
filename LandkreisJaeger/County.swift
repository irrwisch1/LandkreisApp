import Foundation
import MapKit

struct County: Identifiable {
    let id: String
    let name: String
    let kind: String
    let polygons: [MKPolygon]
    let boundingRect: MKMapRect

    var displayName: String { kind.isEmpty ? name : "\(kind) \(name)" }
    var federalState: String { FederalState.name(forKey: String(id.prefix(2))) }

    func contains(_ c: CLLocationCoordinate2D) -> Bool {
        let p = MKMapPoint(c)
        guard boundingRect.contains(p) else { return false }
        return polygons.contains { Geo.polygon($0, contains: p) }
    }

    func nearestBorderPoint(to c: CLLocationCoordinate2D) -> (distance: CLLocationDistance, point: CLLocationCoordinate2D) {
        let p = MKMapPoint(c)
        var best = p
        var bestD2 = Double.infinity

        func check(_ poly: MKPolygon) {
            let n = poly.pointCount
            guard n > 1 else { return }
            let pts = poly.points()
            for i in 0..<n {
                let q = Geo.nearestPoint(onSegment: pts[i], pts[(i + 1) % n], to: p)
                let dx = q.x - p.x, dy = q.y - p.y
                let d2 = dx * dx + dy * dy
                if d2 < bestD2 { bestD2 = d2; best = q }
            }
        }

        for poly in polygons {
            check(poly)
            for hole in poly.interiorPolygons ?? [] { check(hole) }
        }
        return (p.distance(to: best), best.coordinate)
    }
}

enum CountyLoader {
    enum LoadError: LocalizedError {
        case fileMissing
        var errorDescription: String? {
            "counties.geojson wurde nicht im App-Bundle gefunden. Siehe README → „Kreisdaten vorbereiten“."
        }
    }

    static func load() throws -> [County] {
        guard let url = Bundle.main.url(forResource: "counties", withExtension: "geojson") else {
            throw LoadError.fileMissing
        }
        let objects = try MKGeoJSONDecoder().decode(try Data(contentsOf: url))

        var groups: [String: (name: String, kind: String, polygons: [MKPolygon])] = [:]
        for case let feature as MKGeoJSONFeature in objects {
            guard let data = feature.properties,
                  let props = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ags = (props["AGS"] as? String) ?? (props["AGS"] as? Int).map({ String(format: "%05d", $0) })
            else { continue }

            let polygons: [MKPolygon] = feature.geometry.flatMap { geo -> [MKPolygon] in
                switch geo {
                case let multi as MKMultiPolygon: return multi.polygons
                case let poly as MKPolygon: return [poly]
                default: return []
                }
            }
            var entry = groups[ags] ?? (name: props["GEN"] as? String ?? ags,
                                        kind: props["BEZ"] as? String ?? "",
                                        polygons: [])
            entry.polygons += polygons
            groups[ags] = entry
        }

        return groups.map { ags, e in
            County(id: ags, name: e.name, kind: e.kind, polygons: e.polygons,
                     boundingRect: e.polygons.reduce(MKMapRect.null) { $0.union($1.boundingMapRect) })
        }
        .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}
